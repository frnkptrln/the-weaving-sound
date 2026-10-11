import hashlib
import math
from pathlib import Path
import tempfile
import unittest
import wave

import numpy as np
from render import DURATION, PEAK_TARGET, build_score, dry_signal, mix_returns, pcm24, render, synthesize


class HandoffTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.score = build_score()
        cls.full, cls.gain = synthesize(cls.score, 24000)

    def test_form_hands_the_motif_between_voices_and_leaves_space(self):
        events = self.score["events"]
        self.assertEqual(events, sorted(events, key=lambda e: (e["seconds"], e["voice"])))
        self.assertEqual({e["voice"] for e in events if e["seconds"] < 34}, {0})
        self.assertEqual({e["voice"] for e in events if e["phrase"] == 6}, {0, 1, 2})
        self.assertEqual(sum(e["phrase"] == 10 for e in events), 1)
        self.assertLess(max(e["seconds"] + 6 for e in events), 112)

    def test_render_is_finite_stereo_with_headroom_and_silent_ending(self):
        self.assertEqual(self.full.shape, (DURATION * 24000, 2))
        self.assertTrue(np.isfinite(self.full).all())
        self.assertAlmostEqual(float(np.max(np.abs(self.full))), PEAK_TARGET, places=12)
        self.assertFalse(np.array_equal(self.full[:, 0], self.full[:, 1]))
        self.assertEqual(float(np.max(np.abs(self.full[-24000:]))), 0)
        self.assertGreater(float(np.sqrt(np.mean(self.full ** 2))), 0.01)

    def test_memory_carries_sound_after_all_sources_stop_at_shared_gain(self):
        dry = dry_signal(self.score, 24000)
        reference = mix_returns(dry, 24000, memory=False) * self.gain
        self.assertEqual(float(np.max(np.abs(dry[112 * 24000:]))), 0)
        self.assertEqual(float(np.max(np.abs(reference[112 * 24000:]))), 0)
        self.assertGreater(float(np.sqrt(np.mean(self.full[112 * 24000:122 * 24000] ** 2))), 0.0001)
        # Before the first long echo at 9.5 seconds, the versions are identical.
        np.testing.assert_array_equal(self.full[:9 * 24000], reference[:9 * 24000])

    def test_repeat_and_encoded_delivery(self):
        with tempfile.TemporaryDirectory() as directory:
            report = render(Path(directory), sample_rate=24000)
            wav = Path(directory) / "a-place-left-for-you.wav"
            with wave.open(str(wav)) as stream:
                self.assertEqual((stream.getnchannels(), stream.getsampwidth(), stream.getframerate(), stream.getnframes()), (2, 3, 24000, 132 * 24000))
                data = stream.readframes(stream.getnframes())
            self.assertEqual(hashlib.sha256(data).hexdigest(), report["pcm_sha256"])
            self.assertEqual(data, pcm24(self.full))
            self.assertEqual(report["final_second_peak"], 0)
            self.assertAlmostEqual(report["gain_from_full_version"], self.gain)

    def test_pcm_limits_and_sign(self):
        encoded = pcm24(np.array([[0, -1], [1, 0.5]], dtype=float))
        self.assertEqual(encoded[:6], b"\x00\x00\x00\x01\x00\x80")
        for invalid in (math.nan, math.inf, 1.01):
            with self.assertRaises(ValueError):
                pcm24(np.array([[invalid, 0]]))
        with self.assertRaises(ValueError):
            synthesize(self.score, 44100)


if __name__ == "__main__":
    unittest.main()
