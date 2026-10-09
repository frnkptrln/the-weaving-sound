import json
import math
import unittest

import numpy as np
import render


class ScoreTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.score = render.build_score()

    def test_score_repeats_without_random_state(self):
        self.assertEqual(self.score, render.build_score())
        json.dumps(self.score, allow_nan=False)

    def test_every_voice_survives_and_events_stay_in_the_form(self):
        events = self.score["events"]
        self.assertEqual({event["voice"] for event in events}, set(range(6)))
        self.assertEqual(events, sorted(events, key=lambda event: (event["seconds"], event["voice"])))
        for event in events:
            self.assertGreaterEqual(event["seconds"], 0)
            self.assertLessEqual(event["seconds"], render.EVENT_END)
            self.assertIn(event["midi"], render.PITCHES[event["voice"]])
            self.assertTrue(0 < event["velocity"] <= 1)
        for second in self.score["phase_trace"]:
            self.assertTrue(0 <= second["coherence"] <= 1 + 1e-12)

    def test_coupling_changes_timing_without_erasing_pitch_cycles(self):
        independent = render.build_score(coupled=False)
        self.assertTrue(all(point["coupling"] == 0 for point in independent["phase_trace"]))
        # Before the coupling enters, the two schedules really are identical.
        self.assertEqual(
            [event for event in self.score["events"] if event["seconds"] < 18],
            [event for event in independent["events"] if event["seconds"] < 18],
        )
        def mean_coherence(score, start, end):
            values = [point["coherence"] for point in score["phase_trace"] if start <= point["seconds"] < end]
            return sum(values) / len(values)
        # A property of this fixed score, not a claim about arbitrary networks.
        held = mean_coherence(self.score, 45, 60)
        self.assertGreater(held, 0.9)
        self.assertGreater(held, mean_coherence(independent, 45, 60) + 0.3)
        self.assertLess(mean_coherence(self.score, 82, 89), held - 0.2)


class AudioTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.score = {
            "duration_seconds": 8.0,
            "events": [{"seconds": 0.5, "voice": 0, "midi": 62, "velocity": 0.7, "pan": -0.7}],
        }
        cls.audio = render.synthesize(cls.score, 24000)

    def test_output_has_headroom_stereo_and_silent_ending(self):
        self.assertEqual(self.audio.shape, (8 * 24000, 2))
        self.assertTrue(np.isfinite(self.audio).all())
        self.assertAlmostEqual(float(np.max(np.abs(self.audio))), render.PEAK_TARGET)
        self.assertFalse(np.array_equal(self.audio[:, 0], self.audio[:, 1]))
        self.assertTrue(np.all(self.audio[-24000:] == 0))

    def test_pcm_round_trip_including_negative_values(self):
        encoded = render.pcm24(self.audio)
        self.assertEqual(len(encoded), self.audio.size * 3)
        triples = np.frombuffer(encoded, dtype=np.uint8).reshape(-1, 3).astype(np.int32)
        integers = triples[:, 0] | triples[:, 1] << 8 | triples[:, 2] << 16
        integers = (integers ^ 0x800000) - 0x800000
        decoded = integers.reshape(self.audio.shape) / 8388607
        self.assertLessEqual(float(np.max(np.abs(decoded - self.audio))), 0.5 / 8388607 + 1e-15)

    def test_invalid_audio_cannot_be_encoded(self):
        for value in (math.nan, math.inf, -math.inf, 1.01, -1.01):
            with self.subTest(value=value), self.assertRaises(ValueError):
                render.pcm24(np.array([[value, 0.0]]))

    def test_unsupported_rate_and_silence_fail(self):
        with self.assertRaises(ValueError):
            render.synthesize(self.score, 8000)
        with self.assertRaises(ValueError):
            render.synthesize({"duration_seconds": 8.0, "events": []}, 24000)


if __name__ == "__main__":
    unittest.main()
