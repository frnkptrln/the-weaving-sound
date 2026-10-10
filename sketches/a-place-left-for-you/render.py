#!/usr/bin/env python3
"""A finite motif handoff: three voices leave; their shared echoes remain."""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import platform
import tempfile
import wave
from pathlib import Path

DURATION = 132
PEAK_TARGET = 10 ** (-6 / 20)
MOTIF = (0, 7, 9, 4, 2)
OFFSETS = (0, 1.5, 3.75, 5.25, 7.5)
PANS = (-0.68, 0.64, 0.0)
# Start, voice (-1 passes successive notes between all three), motif suffix.
PHRASES = ((2, 0, 0), (13.25, 0, 0), (24.5, 0, 0),
           (35.75, 1, 0), (47, 1, 1), (58.25, 2, 0),
           (69.5, -1, 0), (80.75, -1, 0),
           (92, 1, 2), (99.5, 2, 3), (105.5, 0, 4))


def build_score() -> dict:
    events = []
    for phrase, (start, owner, suffix) in enumerate(PHRASES):
        for note in range(suffix, len(MOTIF)):
            voice = (note + phrase) % 3 if owner == -1 else owner
            # The octave and spectrum change with the speaker; the interval
            # contour stays legible. A last two-note answer becomes one note.
            events.append({"seconds": start + OFFSETS[note] - OFFSETS[suffix],
                           "voice": voice, "midi": (50, 62, 62)[voice] + MOTIF[note],
                           "velocity": (0.64, 0.53, 0.56)[voice] * (1 - 0.055 * note),
                           "pan": PANS[voice], "phrase": phrase, "motif_note": note})
    return {"title": "A place left for you", "version": 1, "status": "sketch",
            "duration_seconds": DURATION, "motif_semitones": list(MOTIF),
            "events": sorted(events, key=lambda e: (e["seconds"], e["voice"])),
            "form": [{"seconds": 0, "name": "one voice"},
                     {"seconds": 34, "name": "other voices arrive"},
                     {"seconds": 69.5, "name": "the phrase passes between them"},
                     {"seconds": 92, "name": "shorter departures"},
                     {"seconds": 112, "name": "only echoes"},
                     {"seconds": 131, "name": "silence"}],
            "memory": {"delay_seconds": [7.5, 11.25], "first_return_gain": [0.24, 0.17],
                       "return_decay": 0.56, "returns_per_line": 6,
                       "description": "Finite, alternating stereo returns of the shared dry bus; not a room model."}}


def dry_signal(score: dict, sample_rate: int):
    import numpy as np

    dry = np.zeros((DURATION * sample_rate, 2), dtype=np.float64)
    colors = (
        ((1, 1.0), (2, 0.26), (3, 0.10), (4, 0.04)),
        ((1, 1.0), (2, 0.08), (3, 0.20), (5, 0.07)),
        ((1, 1.0), (2.003, 0.28), (3.99, 0.13), (7.02, 0.035)),
    )
    for event in score["events"]:
        voice = event["voice"]
        length = round((4.5, 6.0, 5.5)[voice] * sample_rate)
        time = np.arange(length) / sample_rate
        frequency = 440 * 2 ** ((event["midi"] - 69) / 12)
        signal = np.zeros(length)
        for partial, (ratio, weight) in enumerate(colors[voice]):
            if frequency * ratio >= 0.45 * sample_rate:
                continue
            decay = (1.0, 1.6, 1.7)[voice] / (1 + partial * 0.5)
            # The reed's tiny continuous pitch movement is deterministic.
            phase = math.tau * frequency * ratio * time
            if voice == 1:
                phase += 0.055 * np.sin(math.tau * 4.1 * time)
            signal += weight * np.sin(phase) * np.exp(-time / decay)
        attack = (0.012, 0.24, 0.018)[voice]
        signal *= -np.expm1(-time / attack)
        fade = round(0.18 * sample_rate)
        signal[-fade:] *= np.linspace(1, 0, fade) ** 2
        signal *= event["velocity"]
        angle = (event["pan"] + 1) * math.pi / 4
        start = round(event["seconds"] * sample_rate)
        dry[start:start + length, 0] += signal * math.cos(angle)
        dry[start:start + length, 1] += signal * math.sin(angle)
    return dry


def mix_returns(dry, sample_rate: int, *, memory: bool):
    """Each return reads the unchanged source; no accidental recursive writes."""
    import numpy as np

    audio = dry.copy()
    for seconds, gain in ((0.097, 0.12), (0.173, 0.08), (0.311, 0.05)):
        offset = round(seconds * sample_rate)
        audio[offset:] += gain * dry[:-offset, ::-1]
    if memory:
        for seconds, gain in ((7.5, 0.24), (11.25, 0.17)):
            for repeat in range(1, 7):
                offset = round(seconds * repeat * sample_rate)
                source = dry[:-offset, ::-1] if repeat % 2 else dry[:-offset]
                audio[offset:] += gain * 0.56 ** (repeat - 1) * source
    # Keep the form finite: the last eight seconds recede into a full second
    # of digital silence. The same envelope is used for the reference.
    audio[123 * sample_rate:131 * sample_rate] *= np.linspace(1, 0, 8 * sample_rate)[:, None] ** 2
    audio[131 * sample_rate:] = 0
    return audio


def synthesize(score: dict, sample_rate: int, *, memory: bool = True):
    import numpy as np

    if sample_rate not in (24000, 48000):
        raise ValueError("sample rate must be 24000 or 48000 Hz")
    dry = dry_signal(score, sample_rate)
    full = mix_returns(dry, sample_rate, memory=True)
    if not np.isfinite(full).all():
        raise ValueError("render contains non-finite samples")
    peak = float(np.max(np.abs(full)))
    if peak <= 0:
        raise ValueError("render is silent")
    gain = PEAK_TARGET / peak
    # Both versions use the full version's gain, so the dry sources are not
    # independently normalized. This is not a perceptually loudness-matched ABX.
    audio = full if memory else mix_returns(dry, sample_rate, memory=False)
    audio *= gain
    if not np.isfinite(audio).all() or np.max(np.abs(audio)) >= 1:
        raise ValueError("invalid or clipped render")
    return audio, gain


def pcm24(audio) -> bytes:
    import numpy as np

    if not np.isfinite(audio).all() or np.max(np.abs(audio)) > 1:
        raise ValueError("cannot encode invalid or over-range samples")
    values = np.rint(audio * 8388607).astype(np.int32)
    return np.stack([values & 255, (values >> 8) & 255, (values >> 16) & 255], axis=-1).astype(np.uint8).tobytes()


def render(output_dir: Path, *, sample_rate: int = 48000, memory: bool = True) -> dict:
    import numpy as np

    score = build_score()
    audio, gain = synthesize(score, sample_rate, memory=memory)
    encoded = pcm24(audio)
    score_bytes = json.dumps(score, sort_keys=True, separators=(",", ":"), allow_nan=False).encode()
    report = {"score": score, "mode": "shared-echoes" if memory else "memory-off",
              "score_sha256": hashlib.sha256(score_bytes).hexdigest(),
              "pcm_sha256": hashlib.sha256(encoded).hexdigest(),
              "sample_rate": sample_rate, "channels": 2, "sample_width_bytes": 3,
              "frames": len(audio), "gain_from_full_version": gain,
              "peak_dbfs": 20 * math.log10(float(np.max(np.abs(audio)))),
              "rms_dbfs": 20 * math.log10(float(np.sqrt(np.mean(audio ** 2)))),
              "final_second_peak": float(np.max(np.abs(audio[-sample_rate:]))),
              "per_second_rms": [float(np.sqrt(np.mean(block ** 2))) for block in np.split(audio, DURATION)],
              "environment": {"python": platform.python_version(), "numpy": np.__version__, "machine": platform.machine()},
              "hash_scope": "Diagnostic for this environment; CPU math and NumPy versions may change final bits.",
              "listening_status": "Unreviewed sketch. Numeric tests are not a human listening assessment."}
    name = "a-place-left-for-you" + ("" if memory else "-memory-off")
    output_dir.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(dir=output_dir, prefix=".render-") as temporary:
        wav = Path(temporary) / f"{name}.wav"
        with wave.open(str(wav), "wb") as stream:
            stream.setnchannels(2)
            stream.setsampwidth(3)
            stream.setframerate(sample_rate)
            stream.writeframes(encoded)
        metadata = Path(temporary) / f"{name}.json"
        metadata.write_text(json.dumps(report, indent=2, allow_nan=False) + "\n", encoding="utf-8")
        wav.replace(output_dir / wav.name)
        metadata.replace(output_dir / metadata.name)
    return report


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir", type=Path, default=Path(__file__).resolve().parent / "renders")
    parser.add_argument("--sample-rate", type=int, choices=(24000, 48000), default=48000)
    parser.add_argument("--memory-off", action="store_true", help="same source score and gain, without the long returns")
    args = parser.parse_args()
    try:
        report = render(args.output_dir, sample_rate=args.sample_rate, memory=not args.memory_off)
    except (ImportError, OSError, ValueError) as error:
        parser.exit(1, f"render failed: {error}\n")
    print(json.dumps({key: report[key] for key in ("mode", "sample_rate", "frames", "peak_dbfs", "rms_dbfs", "pcm_sha256")}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
