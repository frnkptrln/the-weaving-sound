"""Render every piece offline and measure the result, using only the standard library.

Shared by scripts/build_manifest.py, which writes manifest.json, and by
tests/test_listening.py, which checks a fresh render against that manifest.
Each piece's own renderer keeps its own requirements: SuperCollider for the
sclang pieces, Python packages plus espeak for rooms-change-us.
"""
from __future__ import annotations

from array import array
from dataclasses import asdict, dataclass
import hashlib
import math
import operator
import os
from pathlib import Path
import platform
import re
import shlex
import shutil
import subprocess
import sys
import wave

ROOT = Path(__file__).resolve().parents[1]
PIECES = ROOT / "pieces"
README = ROOT / "README.md"
MANIFEST = ROOT / "manifest.json"
RENDER_TIMEOUT = 600
SILENCE_DBFS = -200.0
# Below this a one-second window counts as silent when fingerprints are compared.
FINGERPRINT_FLOOR_DBFS = -80.0

# README statuses map onto the two words the manifest uses.
STATUS_WORDS = {"Active": "piece", "Study": "study"}
PIECE_ROW = re.compile(
    r"^\|\s*\[`pieces/([^/`]+)/`\]\([^)]*\)\s*\|\s*(.*?)\s*\|\s*(\w+)\s*\|\s*$")
DOCUMENTED_DURATION = re.compile(r"(\d+)-second")
LOAD_PATH = re.compile(r'"([^"]+\.scd)"\s*\)?\s*\.load')
# UGens whose output depends on the server's random state.
RANDOM_UGEN = re.compile(
    r"\b(?:(?:White|Pink|Brown|Gray|Clip)Noise|LFD?(?:Noise[0-3]|ClipNoise)"
    r"|Dust2?|Crackle|CoinGate|(?:T|I|TI|Exp|TExp|Lin|N)?Rand)\b")
EXTERNAL_TOOL = re.compile(r'shutil\.which\("([^"]+)"\)')
REQUIREMENT_NAME = re.compile(r"^\s*([A-Za-z0-9_.-]+)")


@dataclass(frozen=True)
class Piece:
    name: str
    status: str
    focus: str
    kind: str
    render_command: str | None
    render_output: str | None
    documented_duration_seconds: int | None
    sources: tuple[str, ...]
    random_ugens: dict[str, tuple[str, ...]]
    seeded: bool
    hash_scope: str

    @property
    def entry(self) -> Path:
        return ROOT / self.sources[0]

    @property
    def renderable(self) -> bool:
        return self.render_command is not None


@dataclass(frozen=True)
class Measurement:
    sample_rate: int
    channels: int
    bits: int
    duration_seconds: float
    peak_dbfs: float
    rms_dbfs: float
    channel_rms_dbfs: tuple[float, ...]
    tail_peak_dbfs: float
    pcm_sha256: str
    seconds: tuple[tuple[float, ...], ...]


def dbfs(value: float) -> float:
    return round(20 * math.log10(value), 2) if value > 0 else SILENCE_DBFS


def readme_rows() -> dict[str, tuple[str, str]]:
    """Piece name -> (focus, status) from the pieces table in README.md."""
    rows = {}
    for line in README.read_text().splitlines():
        match = PIECE_ROW.match(line)
        if match:
            name, focus, status = match.groups()
            if status not in STATUS_WORDS:
                raise ValueError(f"README lists {name} with unknown status {status!r}")
            rows[name] = (focus, STATUS_WORDS[status])
    return rows


def loaded_sources(entry: Path) -> list[str]:
    """The entry file plus every .scd it loads, transitively, relative to ROOT."""
    found: list[str] = []
    pending = [entry]
    while pending:
        path = pending.pop(0)
        relative = str(path.relative_to(ROOT))
        if relative in found or not path.is_file():
            continue
        found.append(relative)
        if path.suffix != ".scd":
            continue
        for reference in LOAD_PATH.findall(path.read_text()):
            for candidate in (ROOT / reference, path.parent / reference):
                if candidate.is_file():
                    pending.append(candidate.resolve())
                    break
    return found


def discover() -> list[Piece]:
    """Every piece directory, described from the repository alone."""
    rows = readme_rows()
    pieces = []
    for directory in sorted(path for path in PIECES.iterdir() if path.is_dir()):
        name = directory.name
        if name not in rows:
            raise ValueError(f"pieces/{name} is not listed in the README pieces table")
        focus, status = rows[name]
        output = f"pieces/{name}/renders/{name}.wav"
        if (directory / "src/score.scd").is_file():
            kind, command, entry = "finite-score", f"python3 scripts/render_piece.py {name}", "src/score.scd"
        elif (directory / "render.sh").is_file():
            kind, command, entry = "offline-render", f"bash pieces/{name}/render.sh", "src/render.scd"
        elif (directory / "src/render.py").is_file():
            kind, command, entry = "offline-render", f"bash pieces/{name}/start.sh", "src/render.py"
        else:
            kind, command, entry, output = "interactive", None, "src/main.scd", None
        sources = loaded_sources(directory / entry)
        random_ugens = {}
        seeded = False
        for relative in sources:
            text = (ROOT / relative).read_text()
            if relative.endswith(".scd"):
                names = sorted(set(RANDOM_UGEN.findall(text)))
                if names:
                    random_ugens[relative] = tuple(names)
                seeded = seeded or "RandSeed" in text
            elif relative.endswith(".py"):
                seeded = seeded or re.search(r"default_rng\(\s*\d+\s*\)", text) is not None
        duration = DOCUMENTED_DURATION.search(focus)
        # scsynth has no CPU-specific code paths, so its audio hash held across
        # every machine tried. NumPy dispatches sin, exp and tanh loops per CPU
        # SIMD class, so a NumPy render's hash holds only within that class.
        hash_scope = "toolchain" if entry.endswith(".scd") else "machine"
        pieces.append(Piece(
            name=name, status=status, focus=focus, kind=kind,
            render_command=command, render_output=output,
            documented_duration_seconds=int(duration.group(1)) if duration else None,
            sources=tuple(sources), random_ugens=random_ugens, seeded=seeded,
            hash_scope=hash_scope,
        ))
    unlisted = sorted(set(rows) - {piece.name for piece in pieces})
    if unlisted:
        raise ValueError(f"README lists pieces that do not exist: {', '.join(unlisted)}")
    return pieces


def static_entry(piece: Piece) -> dict:
    """The manifest fields that come from the repository, not from a render."""
    entry = asdict(piece)
    entry["sources"] = list(piece.sources)
    entry["random_ugens"] = {path: list(names) for path, names in piece.random_ugens.items()}
    return entry


def missing_requirements(piece: Piece) -> list[str]:
    """Tools or packages this piece's renderer needs that are not available."""
    missing = []
    if piece.entry.suffix == ".scd":
        missing.extend(tool for tool in ("sclang", "scsynth") if shutil.which(tool) is None)
    else:
        text = piece.entry.read_text()
        missing.extend(tool for tool in EXTERNAL_TOOL.findall(text) if shutil.which(tool) is None)
        requirements = piece.entry.parent.parent / "requirements.txt"
        if requirements.is_file():
            names = [match.group(1) for match in map(REQUIREMENT_NAME.match,
                     requirements.read_text().splitlines()) if match]
            probe = subprocess.run(
                [sys.executable, "-c", "import " + ", ".join(names)],
                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False)
            if probe.returncode:
                missing.append("python packages from " + str(requirements.relative_to(ROOT)))
    return missing


def render(piece: Piece, workdir: Path) -> Path:
    """Run the piece's documented render command; return the WAV it produced."""
    if not piece.renderable:
        raise ValueError(f"{piece.name} has no offline render command")
    command = shlex.split(piece.render_command)
    if command[0] == "python3":
        command[0] = sys.executable
    if piece.kind == "finite-score":
        command += ["--output-dir", str(workdir)]
        output = workdir / f"{piece.name}.wav"
    else:
        output = ROOT / piece.render_output
        output.unlink(missing_ok=True)
    env = os.environ.copy()
    # Launchers call python3; make that the interpreter running this code.
    env["PATH"] = str(Path(sys.executable).parent) + os.pathsep + env.get("PATH", "")
    log = workdir / f"{piece.name}.log"
    try:
        result = subprocess.run(
            command, cwd=ROOT, env=env, stdin=subprocess.DEVNULL,
            stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
            text=True, timeout=RENDER_TIMEOUT, check=False)
    except subprocess.TimeoutExpired as error:
        raise RuntimeError(f"{piece.render_command} exceeded {RENDER_TIMEOUT}s") from error
    log.write_text(result.stdout)
    if result.returncode:
        raise RuntimeError(
            f"{piece.render_command} failed ({result.returncode}):\n{result.stdout[-4000:]}")
    if not output.is_file():
        raise RuntimeError(f"{piece.render_command} did not write {output}")
    return output


def score_path(piece: Piece, output: Path) -> Path | None:
    """The OSC score written next to the WAV, when the renderer produces one."""
    candidate = output.with_suffix(".osc")
    return candidate if candidate.is_file() else None


def sha256_of(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


# OSC argument sizes in bytes for the fixed-width type tags; T F N I carry none.
_OSC_FIXED = {"i": 4, "f": 4, "c": 4, "r": 4, "m": 4, "d": 8, "h": 8, "t": 8,
              "T": 0, "F": 0, "N": 0, "I": 0}


def _osc_padded(length: int) -> int:
    return (length + 3) & ~3


def _zero_osc_string(data: bytearray, start: int, end: int) -> int:
    """Zero the padding after a NUL-terminated OSC string; return the next offset."""
    terminator = data.index(0, start, end)
    following = _osc_padded(terminator + 1 - start) + start
    if following > end:
        raise ValueError("OSC string runs past its element")
    data[terminator:following] = bytes(following - terminator)
    return following


def _zero_osc_element(data: bytearray, start: int, end: int) -> None:
    if data[start:start + 8] == b"#bundle\0":
        offset = start + 16  # after the identifier and the time tag
        while offset < end:
            size = int.from_bytes(data[offset:offset + 4], "big", signed=True)
            if size < 0 or offset + 4 + size > end:
                raise ValueError("OSC bundle element runs past its bundle")
            _zero_osc_element(data, offset + 4, offset + 4 + size)
            offset += 4 + size
        return
    offset = _zero_osc_string(data, start, end)  # address
    if offset >= end or data[offset] != ord(","):
        return  # a message without type tags carries no arguments to walk
    tags_start = offset + 1
    offset = _zero_osc_string(data, offset, end)
    tags = data[tags_start:data.index(0, tags_start, end)].decode("ascii")
    for tag in tags:
        if tag in _OSC_FIXED:
            offset += _OSC_FIXED[tag]
        elif tag in "sS":
            offset = _zero_osc_string(data, offset, end)
        elif tag == "b":
            size = int.from_bytes(data[offset:offset + 4], "big", signed=True)
            blob_end = offset + 4 + size
            following = offset + 4 + _osc_padded(size)
            if size < 0 or following > end:
                raise ValueError("OSC blob runs past its element")
            data[blob_end:following] = bytes(following - blob_end)
            offset = following
        else:
            raise ValueError(f"unsupported OSC type tag {tag!r}")
        if offset > end:
            raise ValueError("OSC arguments run past their element")


def score_sha256(path: Path) -> str:
    """SHA-256 of a non-realtime OSC score with all OSC padding set to zero.

    sclang does not clear the bytes that pad a blob (a SynthDef sent with
    /d_recv) to a four-byte boundary, so they hold whatever was in memory:
    the same score written on two machines can differ in exactly those bytes.
    scsynth ignores padding; the hash should too, and keep everything else.
    """
    data = bytearray(path.read_bytes())
    offset = 0
    while offset < len(data):
        size = int.from_bytes(data[offset:offset + 4], "big", signed=True)
        if size <= 0 or offset + 4 + size > len(data):
            raise ValueError(f"{path} is not a sequence of length-prefixed OSC bundles")
        _zero_osc_element(data, offset + 4, offset + 4 + size)
        offset += 4 + size
    return hashlib.sha256(bytes(data)).hexdigest()


def measure(path: Path, tail_seconds: float = 0.5) -> Measurement:
    """Level statistics and a content hash of a 24-bit PCM WAV file."""
    with wave.open(str(path), "rb") as handle:
        channels, width, rate, frames = (handle.getnchannels(), handle.getsampwidth(),
                                         handle.getframerate(), handle.getnframes())
        raw = handle.readframes(frames)
    if width != 3:
        raise ValueError(f"{path.name}: expected 24-bit PCM, got {width * 8}-bit")
    if len(raw) != frames * channels * 3:
        raise ValueError(f"{path.name}: truncated audio data")
    # Widen each 24-bit sample to a 32-bit integer so the array module can do the work.
    widened = bytearray(len(raw) // 3 * 4)
    widened[1::4], widened[2::4], widened[3::4] = raw[0::3], raw[1::3], raw[2::3]
    samples = array("i")
    samples.frombytes(bytes(widened))
    if sys.byteorder != "little":
        samples.byteswap()
    full_scale = float(1 << 31)
    per_channel = [samples[channel::channels] for channel in range(channels)]
    rms = [math.sqrt(sum(map(operator.mul, data, data)) / max(len(data), 1)) / full_scale
           for data in per_channel]
    peak = max((max(max(data), -min(data)) for data in per_channel if len(data)), default=0)
    tail = samples[-int(tail_seconds * rate) * channels:]
    tail_peak = max(max(tail), -min(tail)) if len(tail) else 0
    # One row per second: RMS of each channel, then peak of each channel, in dBFS.
    seconds = []
    for second in range(frames // rate):
        window = samples[second * rate * channels:(second + 1) * rate * channels]
        parts = [window[channel::channels] for channel in range(channels)]
        seconds.append(tuple(
            [dbfs(math.sqrt(sum(map(operator.mul, part, part)) / len(part)) / full_scale)
             for part in parts]
            + [dbfs(max(max(part), -min(part)) / full_scale) for part in parts]))
    return Measurement(
        sample_rate=rate, channels=channels, bits=24,
        duration_seconds=round(frames / rate, 3),
        peak_dbfs=dbfs(peak / full_scale),
        rms_dbfs=dbfs(math.sqrt(sum(value * value for value in rms) / channels)),
        channel_rms_dbfs=tuple(map(dbfs, rms)),
        tail_peak_dbfs=dbfs(tail_peak / full_scale),
        pcm_sha256=hashlib.sha256(raw).hexdigest(),
        seconds=tuple(seconds),
    )


def fingerprint_deviation(expected: list, actual: list) -> float:
    """Largest per-second level difference in dB, treating quiet windows as silent."""
    if len(expected) != len(actual):
        return math.inf
    largest = 0.0
    for expected_row, actual_row in zip(expected, actual):
        for left, right in zip(expected_row, actual_row):
            largest = max(largest, abs(max(left, FINGERPRINT_FLOOR_DBFS)
                                       - max(right, FINGERPRINT_FLOOR_DBFS)))
    return largest


def tool_version(command: list[str]) -> str | None:
    if shutil.which(command[0]) is None:
        return None
    try:
        result = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                text=True, timeout=30, check=False)
    except (OSError, subprocess.TimeoutExpired):
        return None
    first = next((line for line in result.stdout.splitlines() if line.strip()), "")
    return first.strip() or None


def os_release() -> str | None:
    """The distribution name, which fixes the packaged SuperCollider build."""
    try:
        for line in Path("/etc/os-release").read_text().splitlines():
            if line.startswith("PRETTY_NAME="):
                return line.split("=", 1)[1].strip().strip('"')
    except OSError:
        pass
    return platform.mac_ver()[0] or platform.win32_ver()[0] or None


def cpu_model() -> str | None:
    try:
        for line in Path("/proc/cpuinfo").read_text().splitlines():
            if line.startswith("model name"):
                return line.split(":", 1)[1].strip()
    except OSError:
        pass
    return platform.processor() or None


NUMPY_SIMD_PROBE = """
import numpy
from numpy._core._multiarray_umath import __cpu_baseline__, __cpu_dispatch__, __cpu_features__
print(" ".join(__cpu_baseline__) + " | "
      + " ".join(target for target in __cpu_dispatch__ if __cpu_features__.get(target)))
"""


def environment() -> dict:
    """The tools, and the CPU SIMD class, that can change a render's hash."""
    info = {
        "platform": f"{platform.system()}-{platform.machine()}",
        "os": os_release(),
        "cpu": cpu_model(),
        "python": platform.python_version(),
        "sclang": tool_version(["sclang", "-v"]),
        "scsynth": tool_version(["scsynth", "-v"]),
        "espeak": tool_version(["espeak", "--version"]),
    }
    for module in ("numpy", "scipy", "soundfile"):
        probe = subprocess.run(
            [sys.executable, "-c", f"import {module}; print({module}.__version__)"],
            stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True, check=False)
        info[module] = probe.stdout.strip() or None
    # NumPy's baseline and the dispatched SIMD targets this CPU enables. Renders
    # made with different targets differ in their last bits.
    probe = subprocess.run([sys.executable, "-c", NUMPY_SIMD_PROBE],
                           stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True, check=False)
    info["numpy_simd"] = probe.stdout.strip() or None
    return info
