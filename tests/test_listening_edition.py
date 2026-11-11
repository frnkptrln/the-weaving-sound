"""The listening edition enforces hash scopes without rendering any audio."""
from dataclasses import replace
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
import listening
import listening_edition


class EditionVerificationTests(unittest.TestCase):
    def setUp(self):
        self.piece = listening.Piece(
            name="fixture", status="piece", focus="test", kind="offline-render",
            render_command="unused", render_output="unused.wav",
            documented_duration_seconds=1, sources=(), random_ugens={},
            seeded=True, hash_scope="machine",
        )
        self.actual = listening.Measurement(
            sample_rate=48000, channels=2, bits=24, duration_seconds=1.0,
            peak_dbfs=-12.0, rms_dbfs=-30.0, channel_rms_dbfs=(-30.0, -30.0),
            tail_peak_dbfs=-200.0, pcm_sha256="a" * 64,
            seconds=((-30.0, -30.0, -12.0, -12.0),),
        )
        self.entry = {"render": {
            "sample_rate": 48000, "channels": 2, "duration_seconds": 1.0,
            "score_sha256": None, "reproducible": True,
            "pcm_sha256": "b" * 64, "seconds": list(self.actual.seconds),
            "seconds_max_deviation_db": 0,
        }}

    def verify(self, recorded=None, current=None):
        with patch.object(listening, "measure", return_value=self.actual), \
                patch.object(listening, "score_path", return_value=None):
            return listening_edition.verify(
                self.piece, self.entry, Path("unused.wav"), Path("unused"),
                manifest_environment=recorded or {}, current_environment=current or {},
            )

    def test_toolchain_hash_must_match_even_when_cpu_classes_differ(self):
        self.piece = replace(self.piece, hash_scope="toolchain")
        with self.assertRaisesRegex(RuntimeError, "audio hash differs"):
            self.verify({"numpy_simd": "AVX2"}, {"numpy_simd": "AVX512F"})

    def test_machine_hash_must_match_in_the_same_cpu_class(self):
        with self.assertRaisesRegex(RuntimeError, "audio hash differs"):
            self.verify({"numpy_simd": "AVX2"}, {"numpy_simd": "AVX2"})

    def test_matching_audio_hash_is_accepted_without_cpu_metadata(self):
        self.entry["render"]["pcm_sha256"] = self.actual.pcm_sha256
        for scope in ("toolchain", "machine"):
            with self.subTest(scope=scope):
                self.piece = replace(self.piece, hash_scope=scope)
                self.assertTrue(self.verify()["audio_identical_to_manifest"])

    def test_different_known_cpu_classes_allow_levels_without_claiming_identity(self):
        report = self.verify({"numpy_simd": "AVX2"}, {"numpy_simd": "AVX512F"})
        self.assertFalse(report["audio_identical_to_manifest"])
        self.assertEqual(report["per_second_deviation_db"], 0)

    def test_different_cpu_classes_still_require_levels_within_tolerance(self):
        for deviation in (0.05, 0.2):
            with self.subTest(deviation=deviation):
                self.actual = replace(self.actual, seconds=(
                    (-30.0 + deviation, -30.0, -12.0, -12.0),))
                if deviation <= 0.1:
                    report = self.verify({"numpy_simd": "AVX2"}, {"numpy_simd": "AVX512F"})
                    self.assertAlmostEqual(report["per_second_deviation_db"], deviation)
                else:
                    with self.assertRaisesRegex(RuntimeError, "per-second levels stray"):
                        self.verify({"numpy_simd": "AVX2"}, {"numpy_simd": "AVX512F"})

    def test_missing_or_unclear_cpu_metadata_cannot_excuse_a_hash_mismatch(self):
        known = {"numpy_simd": "AVX2"}
        for unknown in ({}, {"numpy_simd": None}, {"numpy_simd": ""},
                        {"numpy_simd": " "}, {"numpy_simd": ["AVX512F"]}):
            for recorded, current in ((known, unknown), (unknown, known), (unknown, unknown)):
                with self.subTest(recorded=recorded, current=current):
                    with self.assertRaisesRegex(RuntimeError, "audio hash differs"):
                        self.verify(recorded, current)

    def test_varying_audio_retains_its_manifest_tolerance(self):
        self.entry["render"].update(reproducible=False, pcm_sha256=None,
                                    seconds_max_deviation_db=0.1)
        self.actual = replace(self.actual, seconds=((-29.4, -30.0, -12.0, -12.0),))
        report = self.verify()
        self.assertIsNone(report["audio_identical_to_manifest"])
        self.assertAlmostEqual(report["per_second_deviation_db"], 0.6)
        self.actual = replace(self.actual, seconds=((-29.2, -30.0, -12.0, -12.0),))
        with self.assertRaisesRegex(RuntimeError, "per-second levels stray"):
            self.verify()

    def test_build_checks_the_hash_scope_before_copying_or_encoding_audio(self):
        with tempfile.TemporaryDirectory() as directory:
            directory = Path(directory)
            manifest = directory / "manifest.json"
            manifest.write_text(json.dumps({
                "generated_with": {"numpy_simd": "AVX2"},
                "pieces": [{"name": self.piece.name, **self.entry}],
            }))
            with (
                patch.object(listening, "MANIFEST", manifest),
                patch.object(listening, "discover", return_value=[self.piece]),
                patch.object(listening, "missing_requirements", return_value=[]),
                patch.object(listening, "environment", return_value={"numpy_simd": "AVX2"}),
                patch.object(listening, "render", return_value=directory / "render.wav"),
                patch.object(listening, "measure", return_value=self.actual),
                patch.object(listening, "score_path", return_value=None),
                patch.object(listening_edition.shutil, "which", return_value="/unused/ffmpeg"),
                patch.object(listening_edition.shutil, "copyfile") as copy,
                patch.object(listening_edition, "encode_mp3") as encode,
            ):
                with self.assertRaisesRegex(RuntimeError, "audio hash differs"):
                    listening_edition.build(directory / "edition")
                copy.assert_not_called()
                encode.assert_not_called()
                self.assertEqual(list((directory / "edition").iterdir()), [])


if __name__ == "__main__":
    unittest.main()
