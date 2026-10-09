#!/usr/bin/env python3
"""Render six clocks finding, and then losing, a shared time. No audio device needed."""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import platform
import tempfile
import wave
from pathlib import Path

DURATION = 96.0
EVENT_END = 89.0
CONTROL_HZ = 200
FREQUENCIES = (0.151, 0.166, 0.179, 0.193, 0.205, 0.219)
INITIAL_PHASES = (0.0, 0.7, 1.8, 3.0, 4.3, 5.4)
PITCHES = (
    (50, 57, 62, 53),
    (57, 60, 65, 62),
    (62, 69, 65, 72, 69),
    (65, 72, 69, 74),
    (69, 74, 72, 77, 74),
    (74, 77, 81, 76),
)
PANS = (-0.82, -0.48, -0.16, 0.16, 0.48, 0.82)
PEAK_TARGET = 10 ** (-6 / 20)


def coupling_at(seconds: float) -> float:
    """An authored arc; K is in radians/second, not a measured social quantity."""
    if seconds < 18 or seconds >= 76:
        return 0.0
    if seconds < 40:
        return 0.85 * (seconds - 18) / 22
    if seconds < 60:
        return 0.85
    return 0.85 * (76 - seconds) / 16


def coherence(phases: list[float]) -> float:
    real = sum(math.cos(phase) for phase in phases) / len(phases)
    imag = sum(math.sin(phase) for phase in phases) / len(phases)
    return math.hypot(real, imag)


def build_score(*, coupled: bool = True) -> dict:
    """Fixed-step, simultaneous Kuramoto updates; one chime per phase crossing."""
    phases = list(INITIAL_PHASES)
    counts = [0] * len(phases)
    events, trace = [], []
    step = 1 / CONTROL_HZ
    for tick in range(round(EVENT_END * CONTROL_HZ)):
        seconds = tick * step
        strength = coupling_at(seconds) if coupled else 0.0
        if tick % CONTROL_HZ == 0:
            trace.append({"seconds": seconds, "coupling": strength, "coherence": coherence(phases)})
        next_phases = [
            phase + step * (
                math.tau * FREQUENCIES[voice]
                + strength * sum(math.sin(other - phase) for other in phases) / len(phases)
            )
            for voice, phase in enumerate(phases)
        ]
        for voice, (before, after) in enumerate(zip(phases, next_phases)):
            boundary = (math.floor(before / math.tau) + 1) * math.tau
            if before < boundary <= after:
                crossing = seconds + step * (boundary - before) / (after - before)
                index = counts[voice]
                events.append({
                    "seconds": crossing,
                    "voice": voice,
                    "midi": PITCHES[voice][index % len(PITCHES[voice])],
                    "velocity": 0.6 + 0.15 * math.sin(index * 0.4 + voice * 0.7),
                    "pan": PANS[voice],
                })
                counts[voice] += 1
        phases = next_phases
    return {
        "title": "Lantern field",
        "version": 1,
        "mode": "coupled" if coupled else "uncoupled",
        "duration_seconds": DURATION,
        "control_hz": CONTROL_HZ,
        "frequencies_hz": list(FREQUENCIES),
        "initial_phases_radians": list(INITIAL_PHASES),
        "events": sorted(events, key=lambda event: (event["seconds"], event["voice"])),
        "phase_trace": trace,
    }


def synthesize(score: dict, sample_rate: int):
    import numpy as np

    if sample_rate not in (24000, 48000):
        raise ValueError("sample rate must be 24000 or 48000 Hz")
    duration = score["duration_seconds"]
    frames = round(duration * sample_rate)
    dry = np.zeros((frames, 2), dtype=np.float64)
    for event in score["events"]:
        start = round(event["seconds"] * sample_rate)
        length = min(round(4.8 * sample_rate), frames - sample_rate - start)
        if length <= 0:
            continue
        time = np.arange(length) / sample_rate
        voice = event["voice"]
        fundamental = 440 * 2 ** ((event["midi"] - 69) / 12)
        signal = np.zeros(length)
        # A harmonic body with a slightly stretched upper shell; each voice
        # keeps its color and position even when the onsets converge.
        for partial, weight in enumerate((1.0, 0.32, 0.17, 0.09, 0.04)):
            ratio = partial + 1 + (voice + 1) * 0.0018 * partial ** 2
            frequency = fundamental * ratio
            if frequency >= sample_rate * 0.45:
                continue
            decay = (1.35 + 0.13 * voice) / (1 + partial * 0.75)
            signal += weight * np.sin(math.tau * frequency * time) * np.exp(-time / decay)
        signal *= -np.expm1(-time / 0.007)
        end_fade = min(length, round(0.08 * sample_rate))
        signal[-end_fade:] *= np.linspace(1, 0, end_fade) ** 2
        signal *= event["velocity"]
        angle = (event["pan"] + 1) * math.pi / 4
        dry[start:start + length, 0] += signal * math.cos(angle)
        dry[start:start + length, 1] += signal * math.sin(angle)

    # Four quiet, finite reflections. No stochastic reverb or accumulating
    # feedback state: the complete render is independent of playback hardware.
    audio = dry.copy()
    for delay, gain in ((0.113, 0.19), (0.197, 0.13), (0.311, 0.09), (0.431, 0.06)):
        offset = round(delay * sample_rate)
        audio[offset:] += gain * dry[:-offset, ::-1]
    fade_frames = min(frames - sample_rate, 6 * sample_rate)
    audio[-sample_rate - fade_frames:-sample_rate] *= np.linspace(1, 0, fade_frames)[:, None] ** 2
    audio[-sample_rate:] = 0
    if not np.isfinite(audio).all():
        raise ValueError("render contains non-finite samples")
    peak = float(np.max(np.abs(audio)))
    if peak <= 0:
        raise ValueError("render is silent")
    audio *= PEAK_TARGET / peak
    return audio


def pcm24(audio) -> bytes:
    import numpy as np

    if not np.isfinite(audio).all() or np.max(np.abs(audio)) > 1:
        raise ValueError("cannot encode invalid or over-range samples")
    integers = np.rint(audio * 8388607).astype(np.int32)
    return np.stack([integers & 255, (integers >> 8) & 255, (integers >> 16) & 255], axis=-1).astype(np.uint8).tobytes()


def render(output_dir: Path, *, sample_rate: int = 48000, coupled: bool = True) -> dict:
    import numpy as np

    score = build_score(coupled=coupled)
    audio = synthesize(score, sample_rate)
    encoded = pcm24(audio)
    score_bytes = json.dumps(score, sort_keys=True, separators=(",", ":"), allow_nan=False).encode()
    report = {
        "score": score,
        "score_sha256": hashlib.sha256(score_bytes).hexdigest(),
        "pcm_sha256": hashlib.sha256(encoded).hexdigest(),
        "sample_rate": sample_rate,
        "channels": 2,
        "sample_width_bytes": 3,
        "frames": len(audio),
        "peak_dbfs": 20 * math.log10(float(np.max(np.abs(audio)))),
        "rms_dbfs": 20 * math.log10(float(np.sqrt(np.mean(audio ** 2)))),
        "final_second_peak": float(np.max(np.abs(audio[-sample_rate:]))),
        "per_second_rms": [float(np.sqrt(np.mean(block ** 2))) for block in np.split(audio, int(DURATION))],
        "environment": {"python": platform.python_version(), "numpy": np.__version__, "machine": platform.machine()},
        "hash_scope": "Diagnostic for this environment; CPU math and NumPy versions can change final bits.",
        "listening_status": "Numerical checks only; human listening review is still required.",
    }
    name = "lantern-field" if coupled else "lantern-field-uncoupled"
    output_dir.mkdir(parents=True, exist_ok=True)
    # Do the full synthesis and validation before replacing earlier outputs.
    with tempfile.TemporaryDirectory(dir=output_dir, prefix=".render-") as temporary:
        wav = Path(temporary) / f"{name}.wav"
        with wave.open(str(wav), "wb") as stream:
            stream.setnchannels(2)
            stream.setsampwidth(3)
            stream.setframerate(sample_rate)
            stream.writeframes(encoded)
        metadata = Path(temporary) / f"{name}.json"
        metadata.write_text(json.dumps(report, indent=2, allow_nan=False) + "\n")
        wav.replace(output_dir / wav.name)
        metadata.replace(output_dir / metadata.name)
    return report


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir", type=Path, default=Path(__file__).resolve().parent / "renders")
    parser.add_argument("--sample-rate", type=int, choices=(24000, 48000), default=48000)
    parser.add_argument("--uncoupled", action="store_true", help="keep all six clocks independent for an A/B reference")
    args = parser.parse_args()
    try:
        report = render(args.output_dir, sample_rate=args.sample_rate, coupled=not args.uncoupled)
    except (ImportError, OSError, ValueError) as error:
        parser.exit(1, f"render failed: {error}\n")
    print(json.dumps({key: report[key] for key in ("sample_rate", "frames", "peak_dbfs", "rms_dbfs", "pcm_sha256")}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
