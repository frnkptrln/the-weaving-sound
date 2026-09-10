"""Offline audio validation and PCM conversion, without SuperCollider."""
from pathlib import Path
import struct
import sys
import tempfile
import unittest
import wave

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
from audio_file import read_float_wav
from render_piece import export_audio


class AudioIOTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.directory = Path(temporary.name)
        self.source = self.directory / "source.wav"
        self.output = self.directory / "output.wav"

    def write_float_wav(self, data, fmt=None):
        if fmt is None:
            fmt = struct.pack("<HHIIHH", 3, 2, 48000, 384000, 8, 32)
        chunks = bytearray()
        for kind, payload in ((b"fmt ", fmt), (b"data", data)):
            chunks.extend(struct.pack("<4sI", kind, len(payload)))
            chunks.extend(payload)
            if len(payload) % 2:
                chunks.append(0)
        self.source.write_bytes(b"RIFF" + struct.pack("<I", len(chunks) + 4)
                                + b"WAVE" + chunks)

    def finite_fixture(self, first_sample=0.25):
        # A signed stereo impulse followed by more than one second of silence.
        frames = 48480
        self.write_float_wav(struct.pack("<ff", first_sample, -0.5)
                             + bytes((frames - 1) * 8))
        return frames / 48000

    def test_short_format_chunk_is_rejected(self):
        self.write_float_wav(bytes(8), fmt=bytes(15))
        with self.assertRaises(ValueError):
            read_float_wav(self.source)

    def test_incomplete_float_sample_is_rejected(self):
        self.write_float_wav(bytes(3))
        with self.assertRaises(ValueError):
            read_float_wav(self.source)

    def test_incomplete_stereo_frame_is_rejected(self):
        self.write_float_wav(struct.pack("<f", 0.25))
        with self.assertRaises(ValueError):
            read_float_wav(self.source)

    def test_clipping_is_rejected_before_pcm_conversion(self):
        duration = self.finite_fixture(first_sample=1.25)
        with self.assertRaises(ValueError):
            export_audio(self.source, self.output, duration)
        self.assertFalse(self.output.exists())

    def test_nonfinite_samples_are_rejected(self):
        duration = self.finite_fixture(first_sample=float("nan"))
        with self.assertRaises(ValueError):
            export_audio(self.source, self.output, duration)

    def test_nan_duration_is_rejected(self):
        self.finite_fixture()
        with self.assertRaises(ValueError):
            export_audio(self.source, self.output, float("nan"))

    def test_stereo_export_preserves_signed_24bit_samples(self):
        duration = self.finite_fixture()
        report = export_audio(self.source, self.output, duration)
        with wave.open(str(self.output), "rb") as audio:
            self.assertEqual((audio.getnchannels(), audio.getsampwidth(),
                              audio.getframerate(), audio.getnframes()),
                             (2, 3, 48000, 48480))
            frame = audio.readframes(1)
        self.assertEqual(int.from_bytes(frame[:3], "little", signed=True), 2097152)
        self.assertEqual(int.from_bytes(frame[3:], "little", signed=True), -4194304)
        self.assertEqual(report["final_second_peak"], 0)
        self.assertAlmostEqual(report["duration_seconds"], duration)


if __name__ == "__main__":
    unittest.main()
