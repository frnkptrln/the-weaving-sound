"""Small audio-file helpers shared by offline rendering and audio validation."""
from array import array
from pathlib import Path
import struct
import sys


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
    if len(fmt) < 16:
        raise ValueError(f"{path.name}: truncated WAV format")
    encoding, channels, rate, _, _, bits = struct.unpack_from("<HHIIHH", fmt)
    if encoding == 0xFFFE and len(fmt) >= 40:
        encoding = struct.unpack_from("<H", fmt, 24)[0]
    if encoding != 3 or bits != 32:
        raise ValueError(f"{path.name}: expected 32-bit float WAV")
    if channels < 1 or len(data) % (4 * channels):
        raise ValueError(f"{path.name}: incomplete audio frame")
    samples = array("f")
    samples.frombytes(data)
    if sys.byteorder != "little":
        samples.byteswap()
    return channels, rate, samples
