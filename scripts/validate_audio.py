#!/usr/bin/env python3
"""Compile curated SC code and render engine/FX smoke tests without audio hardware.

Requires sclang, scsynth, and sc3-plugins (Decimator for the digital engine).
Run: python3 scripts/validate_audio.py
Use --keep-renders DIR to retain the WAV files and process logs for inspection.
"""
from __future__ import annotations

import argparse
from array import array
import math
import os
from pathlib import Path
import shutil
import struct
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
SAMPLE_RATE = 44100


def run(command: list[str], scratch: Path, env: dict[str, str], timeout: int) -> None:
    """Keep language errors, server failures, and hanging class compilation fatal."""
    log = scratch / (Path(command[0]).name + ".log")
    try:
        result = subprocess.run(
            command, cwd=scratch, env=env, stdin=subprocess.DEVNULL,
            stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
            text=True, timeout=timeout, check=False,
        )
    except subprocess.TimeoutExpired as error:
        output = error.stdout or b""
        log.write_bytes(output if isinstance(output, bytes) else output.encode())
        raise RuntimeError(f"{command[0]} exceeded {timeout}s; see {log}") from error
    with log.open("a") as handle:
        handle.write(result.stdout)
    errors = ("ERROR:", "FAILURE IN SERVER", "exception in GrafDef", "UGen not installed")
    if result.returncode or any(marker in result.stdout for marker in errors):
        raise RuntimeError(f"{command[0]} failed ({result.returncode}):\n{result.stdout[-6000:]}")
    if Path(command[0]).name == "sclang" and "WEAVING_AUDIO_SCORES_READY" not in result.stdout:
        raise RuntimeError("sclang exited before completing the validation scores")


def read_float_wav(path: Path) -> tuple[int, int, array]:
    """Read scsynth's IEEE float WAV using only the standard library."""
    with path.open("rb") as handle:
        header = handle.read(12)
        if header[:4] != b"RIFF" or header[8:] != b"WAVE":
            raise ValueError(f"{path.name}: expected RIFF/WAVE")
        fmt = data = None
        while chunk_header := handle.read(8):
            if len(chunk_header) != 8:
                raise ValueError(f"{path.name}: truncated WAV chunk")
            kind, size = struct.unpack("<4sI", chunk_header)
            chunk = handle.read(size)
            if len(chunk) != size:
                raise ValueError(f"{path.name}: truncated WAV data")
            if kind == b"fmt ":
                fmt = chunk
            elif kind == b"data":
                data = chunk
            if size % 2:
                handle.read(1)
    if fmt is None or data is None:
        raise ValueError(f"{path.name}: missing format/audio data")
    encoding, channels, rate, _, _, bits = struct.unpack_from("<HHIIHH", fmt)
    if encoding == 0xFFFE and len(fmt) >= 40:
        encoding = struct.unpack_from("<H", fmt, 24)[0]
    if encoding != 3 or bits != 32:
        raise ValueError(f"{path.name}: expected 32-bit float WAV")
    samples = array("f")
    samples.frombytes(data)
    if sys.byteorder != "little":
        samples.byteswap()
    return channels, rate, samples


def check_audio(path: Path, duration: float, gate: float) -> str:
    channels, rate, samples = read_float_wav(path)
    if channels != 2 or rate != SAMPLE_RATE:
        raise ValueError(f"{path.stem}: expected stereo/{SAMPLE_RATE} Hz")
    if abs(len(samples) / (channels * rate) - duration) > 0.02:
        raise ValueError(f"{path.stem}: unexpected render duration")
    if not samples or not all(math.isfinite(value) for value in samples):
        raise ValueError(f"{path.stem}: empty audio or non-finite samples")
    peaks = [max(map(abs, samples[channel::channels])) for channel in range(channels)]
    peak = max(peaks)
    if min(peaks) < 1e-6:
        raise ValueError(f"{path.stem}: a channel is silent ({peaks})")
    if peak >= 1.0:
        raise ValueError(f"{path.stem}: clipping (peak {peak:.6f})")
    # All source envelopes should have ended; the long FX score lets reverb decay.
    tail = max(map(abs, samples[-int(0.25 * rate * channels):]))
    if tail > max(1e-6, peak * 0.001):
        raise ValueError(f"{path.stem}: release/tail did not settle ({tail:.6f})")
    if gate >= 0:
        release = samples[int((gate + 0.05) * rate * channels):int((gate + 0.2) * rate * channels)]
        if max(map(abs, release), default=0) < 1e-7:
            raise ValueError(f"{path.stem}: gate-off cut the release abruptly")
    return f"{path.stem}: stereo, peak {peak:.4f}, tail {tail:.2g}, {duration:g}s"


def validate(scratch: Path) -> None:
    for program in ("sclang", "scsynth"):
        if shutil.which(program) is None:
            raise RuntimeError(f"Missing {program}; install SuperCollider and sc3-plugins")
    env = os.environ.copy()
    env.update(QT_QPA_PLATFORM="offscreen", QTWEBENGINE_DISABLE_SANDBOX="1")
    # Avoid user startup files and keep SuperCollider/Qt state in disposable scratch.
    for variable, relative in (
        ("XDG_CONFIG_HOME", "config"), ("XDG_DATA_HOME", "data"),
        ("XDG_CACHE_HOME", "cache"), ("XDG_RUNTIME_DIR", "runtime"),
    ):
        directory = scratch / relative
        directory.mkdir(mode=0o700, exist_ok=True)
        env[variable] = str(directory)
    sources = sorted(
        path for folder in ("core", "engines", "pieces")
        for path in (ROOT / folder).rglob("*.scd")
    )
    (scratch / "sources.txt").write_text("\n".join(map(str, sources)) + "\n")
    run(["sclang", "-D", "-u", "0", str(ROOT / "scripts/validate_audio.scd"),
         str(ROOT), str(scratch)], scratch, env, timeout=90)
    cases = (scratch / "cases.tsv").read_text().splitlines()
    for line in cases:
        name, duration, gate = line.split("\t")
        wav = scratch / f"{name}.wav"
        run(["scsynth", "-N", str(scratch / f"{name}.osc"), "_", str(wav),
             str(SAMPLE_RATE), "WAV", "float", "-i", "0", "-o", "2",
             "-D", "0", "-m", "65536", "-V", "-1"], scratch, env, timeout=60)
        print(check_audio(wav, float(duration), float(gate)))
    if len(cases) != 12:
        raise RuntimeError(f"Expected 12 voice/FX checks, got {len(cases)}")
    print(f"Audio validation passed ({len(sources)} SC sources, {len(cases)} NRT renders)")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--keep-renders", type=Path, metavar="DIR")
    args = parser.parse_args()
    try:
        if args.keep_renders:
            scratch = args.keep_renders.resolve()
            scratch.mkdir(parents=True, exist_ok=True)
            validate(scratch)
        else:
            with tempfile.TemporaryDirectory(prefix="weaving-audio-") as directory:
                validate(Path(directory))
    except (OSError, RuntimeError, ValueError) as error:
        print(f"Audio validation failed: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
