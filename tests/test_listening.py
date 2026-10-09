"""Listening test: render each piece offline and check the audio against manifest.json.

One test per piece. A piece whose renderer's tools are missing is skipped with
the reason; a piece with no offline render path is skipped and says so. The
static tests at the end need no tools and keep the manifest honest.
"""
from __future__ import annotations

import json
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
import listening  # noqa: E402

MANIFEST = json.loads(listening.MANIFEST.read_text())
ENTRIES = {entry["name"]: entry for entry in MANIFEST["pieces"]}
PIECES = {piece.name: piece for piece in listening.discover()}

EXPECTED_CHANNELS = 2          # every renderer writes stereo (core/README.md)
DURATION_TOLERANCE = 0.05      # seconds; scsynth may append one final block
RMS_FLOOR_DBFS = -40.0         # below this the render counts as silent
CHANNEL_RMS_FLOOR_DBFS = -45.0
CLIP_PEAK_DBFS = -0.1          # a peak at or above this counts as clipping
TAIL_CEILING_DBFS = -80.0      # every piece documents an ending in silence
PEAK_TOLERANCE_DB = 3.0        # for pieces whose audio varies between renders
RMS_TOLERANCE_DB = 1.0
FINGERPRINT_TOLERANCE_DB = 0.1  # per second, for reproducible audio on another CPU class
FINGERPRINT_MARGIN_DB = 0.5     # added to twice the deviation the manifest build observed


class ListeningTests(unittest.TestCase):
    """Generated per piece below: test_<piece>_renders."""

    @staticmethod
    def hash_advice() -> str:
        """Distinguish a changed render from a changed toolchain."""
        recorded, current = MANIFEST["generated_with"], listening.environment()
        differences = {key: (recorded.get(key), current.get(key))
                       for key in sorted(set(recorded) | set(current))
                       if recorded.get(key) != current.get(key)}
        if differences:
            return ("audio differs and so does the toolchain (manifest, this run): "
                    f"{differences}; the change may come from the tools, not the piece. "
                    "Rerun scripts/build_manifest.py in the environment that should be the reference")
        return ("audio changed in the same toolchain the manifest was built with; "
                "rerun scripts/build_manifest.py if the change is intended")

    @staticmethod
    def same_hash_scope(piece: listening.Piece) -> bool:
        """Whether the recorded audio hash applies to this machine at all."""
        if piece.hash_scope == "toolchain":
            return True
        recorded = MANIFEST["generated_with"].get("numpy_simd")
        return recorded is not None and recorded == listening.environment().get("numpy_simd")

    def render_and_check(self, name: str) -> None:
        piece, entry = PIECES[name], ENTRIES[name]
        if not piece.renderable:
            self.skipTest(f"{name} is interactive; it has no offline render path")
        missing = listening.missing_requirements(piece)
        if missing:
            self.skipTest(f"{name} needs {', '.join(missing)}")
        expected = entry["render"]
        self.assertIsNotNone(expected, f"{name} is renderable but manifest.json has no render")
        with tempfile.TemporaryDirectory(prefix=f"listening-{name}-") as directory:
            output = listening.render(piece, Path(directory))
            actual = listening.measure(output)
            score = listening.score_path(piece, output)
            score_hash = listening.sha256_of(score) if score else None

        with self.subTest(check="channels"):
            self.assertEqual(actual.channels, EXPECTED_CHANNELS)
            self.assertEqual(actual.channels, expected["channels"])
        with self.subTest(check="sample rate"):
            self.assertEqual(actual.sample_rate, expected["sample_rate"])
        with self.subTest(check="duration"):
            self.assertAlmostEqual(actual.duration_seconds, expected["duration_seconds"],
                                   delta=DURATION_TOLERANCE)
            if piece.documented_duration_seconds is not None:
                self.assertAlmostEqual(actual.duration_seconds, piece.documented_duration_seconds,
                                       delta=DURATION_TOLERANCE,
                                       msg="render does not last as long as the README says")
        with self.subTest(check="not silent"):
            self.assertGreater(actual.rms_dbfs, RMS_FLOOR_DBFS)
            for channel, rms in enumerate(actual.channel_rms_dbfs):
                self.assertGreater(rms, CHANNEL_RMS_FLOOR_DBFS, f"channel {channel} is silent")
        with self.subTest(check="no clipping"):
            self.assertLess(actual.peak_dbfs, CLIP_PEAK_DBFS)
        with self.subTest(check="ends in silence"):
            self.assertLessEqual(actual.tail_peak_dbfs, TAIL_CEILING_DBFS)
        with self.subTest(check="score hash"):
            self.assertEqual(score_hash, expected["score_sha256"],
                             "the OSC score changed; rerun scripts/build_manifest.py if intended")
        deviation = listening.fingerprint_deviation(expected["seconds"], list(actual.seconds))
        if expected["reproducible"] and self.same_hash_scope(piece):
            with self.subTest(check="audio hash"):
                self.assertEqual(actual.pcm_sha256, expected["pcm_sha256"], self.hash_advice())
        elif expected["reproducible"]:
            # Same audio on another CPU SIMD class differs only in its last bits.
            print(f"[{name}] hash not compared: NumPy SIMD class differs from the manifest "
                  f"({MANIFEST['generated_with'].get('numpy_simd')!r}); "
                  f"checking per-second levels within {FINGERPRINT_TOLERANCE_DB} dB instead")
            with self.subTest(check="per-second levels"):
                self.assertLessEqual(deviation, FINGERPRINT_TOLERANCE_DB,
                                     "levels changed; rerun scripts/build_manifest.py if intended")
                self.assertAlmostEqual(actual.peak_dbfs, expected["peak_dbfs"],
                                       delta=FINGERPRINT_TOLERANCE_DB)
                self.assertAlmostEqual(actual.rms_dbfs, expected["rms_dbfs"],
                                       delta=FINGERPRINT_TOLERANCE_DB)
        else:
            tolerance = 2 * expected["seconds_max_deviation_db"] + FINGERPRINT_MARGIN_DB
            with self.subTest(check="levels within tolerance"):
                self.assertAlmostEqual(actual.peak_dbfs, expected["peak_dbfs"],
                                       delta=PEAK_TOLERANCE_DB)
                self.assertAlmostEqual(actual.rms_dbfs, expected["rms_dbfs"],
                                       delta=RMS_TOLERANCE_DB)
                self.assertLessEqual(deviation, tolerance,
                                     "a second strayed further than the manifest build observed")


def _piece_test(name: str):
    def test(self):
        self.render_and_check(name)
    test.__doc__ = f"{name}: render offline and compare with manifest.json"
    return test


for _name in sorted(ENTRIES):
    setattr(ListeningTests, f"test_{_name.replace('-', '_')}_renders", _piece_test(_name))


class ManifestTests(unittest.TestCase):
    """manifest.json is generated; these checks need no synthesis tools."""

    def test_manifest_lists_exactly_the_pieces_in_the_repository(self):
        self.assertEqual(sorted(ENTRIES), sorted(PIECES))

    def test_manifest_static_fields_match_the_repository(self):
        for name, piece in PIECES.items():
            with self.subTest(piece=name):
                expected = listening.static_entry(piece)
                actual = {key: ENTRIES[name][key] for key in expected}
                self.assertEqual(actual, expected,
                                 "manifest.json is stale; rerun scripts/build_manifest.py")

    def test_renderable_pieces_have_a_recorded_render(self):
        for name, piece in PIECES.items():
            with self.subTest(piece=name):
                render = ENTRIES[name]["render"]
                if piece.renderable:
                    self.assertIsNotNone(render)
                    self.assertIn(render["reproducible"], (True, False))
                    if render["reproducible"]:
                        self.assertRegex(render["pcm_sha256"], r"^[0-9a-f]{64}$")
                        self.assertEqual(render["seconds_max_deviation_db"], 0)
                    else:
                        self.assertIsNone(render["pcm_sha256"])
                    self.assertEqual(len(render["seconds"]), int(render["duration_seconds"]))
                else:
                    self.assertIsNone(render)

    def test_unseeded_random_ugens_explain_every_varying_render(self):
        for name, piece in PIECES.items():
            render = ENTRIES[name]["render"]
            if render and not render["reproducible"]:
                with self.subTest(piece=name):
                    self.assertTrue(piece.random_ugens and not piece.seeded,
                                    "audio varies without an unseeded random UGen to blame")

    def test_reproducible_python_renderers_pin_their_packages(self):
        # Regression: rooms-change-us rendered a different hash on CI because
        # pip resolved newer NumPy and SciPy than the manifest was built with.
        # A recorded audio hash is only meaningful with an exactly pinned toolchain.
        for name, piece in PIECES.items():
            render = ENTRIES[name]["render"]
            requirements = piece.entry.parent.parent / "requirements.txt"
            if not (render and render["reproducible"] and requirements.is_file()):
                continue
            with self.subTest(piece=name):
                lines = [line.split("#")[0].strip() for line in requirements.read_text().splitlines()]
                for requirement in filter(None, lines):
                    self.assertRegex(requirement, r"^[A-Za-z0-9_.-]+==\S+$",
                                     f"{name}: pin {requirement!r} exactly, the audio hash depends on it")

    def test_declared_status_agrees_with_readme(self):
        # Pieces that declare status through the metadata contract must match the README table.
        for name, piece in PIECES.items():
            text = piece.entry.read_text()
            if "~weavingPiece" not in text:
                continue
            with self.subTest(piece=name):
                declared = "study" if "status: \\study" in text else "piece"
                self.assertEqual(piece.status, declared)


if __name__ == "__main__":
    unittest.main()
