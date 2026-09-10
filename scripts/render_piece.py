#!/usr/bin/env python3
"""Render finite SuperCollider scores to checked stereo WAV and optional MP3.

Usage: python3 scripts/render_piece.py phase-weave spectral-memory
Requires Python 3.10+, sclang, scsynth; ffmpeg is optional for MP3.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import wave

from audio_file import read_float_wav

ROOT = Path(__file__).resolve().parents[1]
SAMPLE_RATE = 48000


def run(command: list[str], scratch: Path, env: dict[str, str], marker: str = "") -> None:
    try:
        result = subprocess.run(
            command, cwd=scratch, env=env, stdin=subprocess.DEVNULL,
            stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
            text=True, timeout=120, check=False,
        )
    except subprocess.TimeoutExpired as error:
        raise RuntimeError(f"{command[0]} exceeded 120 seconds") from error
    if result.returncode or any(text in result.stdout for text in (
        "ERROR:", "FAILURE IN SERVER", "exception in GrafDef", "UGen not installed",
    )) or (marker and marker not in result.stdout):
        raise RuntimeError(f"{command[0]} failed ({result.returncode}):\n{result.stdout[-5000:]}")


def export_audio(source: Path, output: Path, duration: float) -> dict:
    if not math.isfinite(duration) or not 0 < duration <= 600:
        raise ValueError("Score duration must be finite and between 0 and 600 seconds")
    channels, rate, samples = read_float_wav(source)
    if channels != 2 or rate != SAMPLE_RATE:
        raise ValueError("Expected stereo audio at 48000 Hz")
    if abs(len(samples) / (channels * rate) - duration) > 0.02:
        raise ValueError("Rendered audio does not match the score duration")
    if not samples or not all(math.isfinite(sample) for sample in samples):
        raise ValueError("Render contains no audio or non-finite samples")
    peaks = [max(map(abs, samples[channel::channels])) for channel in range(channels)]
    peak = max(peaks)
    if min(peaks) < 1e-6:
        raise ValueError("One or both channels are silent")
    if peak >= 1:
        raise ValueError(f"Render clips before PCM conversion (peak {peak:.4f})")
    tail = max(map(abs, samples[-rate * channels:]))
    if tail > 1e-6:
        raise ValueError(f"Final second has not reached silence (peak {tail:.6f})")
    rms = math.sqrt(sum(sample * sample for sample in samples) / len(samples))
    # Validate float audio before integer conversion can conceal over-range values.
    pcm = bytearray(len(samples) * 3)
    for index, sample in enumerate(samples):
        integer = max(-8388608, min(8388607, round(sample * 8388608))) & 0xFFFFFF
        offset = index * 3
        pcm[offset] = integer & 255
        pcm[offset + 1] = (integer >> 8) & 255
        pcm[offset + 2] = (integer >> 16) & 255
    with wave.open(str(output), "wb") as wav:
        wav.setnchannels(channels)
        wav.setsampwidth(3)
        wav.setframerate(rate)
        wav.writeframes(pcm)
    return dict(
        duration_seconds=len(samples) / (channels * rate),
        sample_rate=rate, channels=channels, pcm_bits=24,
        peak_dbfs=round(20 * math.log10(peak), 3),
        rms_dbfs=round(20 * math.log10(rms), 3), final_second_peak=tail,
    )


def render(name: str, output_dir: Path | None = None) -> Path:
    for program in ("sclang", "scsynth"):
        if shutil.which(program) is None:
            raise RuntimeError(f"Missing {program}; install SuperCollider")
    destination = (output_dir or ROOT / "pieces" / name / "renders").resolve()
    destination.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix=".render-", dir=destination) as directory:
        scratch = Path(directory)
        env = os.environ.copy()
        env.update(QT_QPA_PLATFORM="offscreen", QTWEBENGINE_DISABLE_SANDBOX="1")
        for variable, relative in (
            ("XDG_CONFIG_HOME", "config"), ("XDG_DATA_HOME", "data"),
            ("XDG_CACHE_HOME", "cache"), ("XDG_RUNTIME_DIR", "runtime"),
        ):
            target = scratch / relative
            target.mkdir(mode=0o700)
            env[variable] = str(target)
        run(["sclang", "-D", "-u", "0", str(ROOT / "scripts/render_piece.scd"),
             str(ROOT), name, str(scratch)], scratch, env, "WEAVING_PIECE_SCORE_READY")
        duration = float((scratch / "duration.txt").read_text())
        run(["scsynth", "-N", str(scratch / "score.osc"), "_", str(scratch / "float.wav"),
             str(SAMPLE_RATE), "WAV", "float", "-i", "0", "-o", "2",
             "-D", "0", "-m", "65536", "-V", "-1"], scratch, env)
        wav_name = f"{name}.wav"
        report = export_audio(scratch / "float.wav", scratch / wav_name, duration)
        report["piece"] = name
        report["score_sha256"] = hashlib.sha256((scratch / "score.osc").read_bytes()).hexdigest()
        outputs = [wav_name, f"{name}.json", f"{name}.osc"]
        shutil.copyfile(scratch / "score.osc", scratch / outputs[2])
        report["mp3_created"] = shutil.which("ffmpeg") is not None
        if report["mp3_created"]:
            mp3_name = f"{name}.mp3"
            run(["ffmpeg", "-nostdin", "-hide_banner", "-loglevel", "error",
                 "-i", str(scratch / wav_name), "-codec:a", "libmp3lame", "-b:a", "256k",
                 str(scratch / mp3_name)], scratch, env)
            outputs.append(mp3_name)
        (scratch / outputs[1]).write_text(json.dumps(report, indent=2) + "\n")
        # Publish only after synthesis, checks, and optional encoding have succeeded.
        for filename in outputs:
            os.replace(scratch / filename, destination / filename)
        if not report["mp3_created"]:
            # A previous encoded version must not appear to match the new WAV.
            (destination / f"{name}.mp3").unlink(missing_ok=True)
    print(f"{name}: {report['duration_seconds']:.2f}s, stereo, "
          f"peak {report['peak_dbfs']:.2f} dBFS, silent ending\n{destination / wav_name}")
    return destination / wav_name


def main() -> int:
    available = sorted(path.parent.parent.name for path in (ROOT / "pieces").glob("*/src/score.scd"))
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("pieces", nargs="+", choices=available)
    parser.add_argument("--output-dir", type=Path, help="Defaults to each piece's renders directory")
    args = parser.parse_args()
    try:
        for name in args.pieces:
            render(name, args.output_dir)
    except (OSError, RuntimeError, ValueError) as error:
        print(f"Render failed: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
