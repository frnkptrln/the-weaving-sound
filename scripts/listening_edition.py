#!/usr/bin/env python3
"""Render the anthology's finite pieces into a listening edition.

The edition is the audio that manifest.json describes, made audible without
SuperCollider: one MP3 per renderable piece, the WAV it was encoded from, and
an edition.json that ties every file to the manifest's score and audio hashes.
A render that does not match the manifest stops the build — the edition must
be the recorded audio, not a variant of it.

Usage: python3 scripts/listening_edition.py --output renders/edition
Requires the same tools as the listening test (sclang, scsynth, the
rooms-change-us packages, espeak) plus ffmpeg for the MP3s.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile

sys.path.insert(0, str(Path(__file__).resolve().parent))
import listening  # noqa: E402

MP3_BITRATE = "256k"
REPOSITORY = "https://github.com/frnkptrln/the-weaving-sound"


def encode_mp3(wav: Path, mp3: Path, title: str) -> None:
    subprocess.run(
        ["ffmpeg", "-nostdin", "-hide_banner", "-loglevel", "error", "-y",
         "-i", str(wav), "-codec:a", "libmp3lame", "-b:a", MP3_BITRATE,
         "-metadata", f"title={title}", "-metadata", "album=the-weaving-sound",
         "-metadata", "artist=frnkptrln", str(mp3)],
        check=True, stdin=subprocess.DEVNULL)


def verify(piece: listening.Piece, entry: dict, output: Path, workdir: Path) -> dict:
    """Compare a fresh render with the manifest; raise on any disagreement."""
    expected = entry["render"]
    actual = listening.measure(output)
    problems = []
    if actual.channels != expected["channels"] or actual.sample_rate != expected["sample_rate"]:
        problems.append("channel count or sample rate differs from the manifest")
    if abs(actual.duration_seconds - expected["duration_seconds"]) > 0.05:
        problems.append(f"duration {actual.duration_seconds:.3f}s, manifest {expected['duration_seconds']}s")
    score = listening.score_path(piece, output)
    score_hash = listening.score_sha256(score) if score else None
    if score_hash != expected["score_sha256"]:
        problems.append("the OSC score differs from the manifest")
    deviation = listening.fingerprint_deviation(expected["seconds"], list(actual.seconds))
    audio_hash_matches = None
    if expected["reproducible"]:
        audio_hash_matches = actual.pcm_sha256 == expected["pcm_sha256"]
        if not audio_hash_matches and deviation > 0.1:
            problems.append(f"per-second levels stray {deviation:.2f} dB from the manifest")
    else:
        tolerance = 2 * expected["seconds_max_deviation_db"] + 0.5
        if deviation > tolerance:
            problems.append(f"per-second levels stray {deviation:.2f} dB, beyond the manifest's {tolerance:.2f} dB")
    if problems:
        raise RuntimeError(f"{piece.name}: " + "; ".join(problems))
    return {
        "duration_seconds": round(actual.duration_seconds, 3),
        "peak_dbfs": actual.peak_dbfs,
        "rms_dbfs": actual.rms_dbfs,
        "score_sha256": score_hash,
        "pcm_sha256": actual.pcm_sha256,
        "manifest_pcm_sha256": expected["pcm_sha256"],
        "audio_identical_to_manifest": audio_hash_matches,
        "per_second_deviation_db": round(deviation, 3),
        "reproducible": expected["reproducible"],
    }


def build(destination: Path) -> dict:
    if shutil.which("ffmpeg") is None:
        raise RuntimeError("ffmpeg is required for the MP3 encodes")
    manifest = json.loads(listening.MANIFEST.read_text())
    entries = {entry["name"]: entry for entry in manifest["pieces"]}
    pieces = [piece for piece in listening.discover() if piece.renderable]
    blocked = {piece.name: listening.missing_requirements(piece) for piece in pieces}
    blocked = {name: missing for name, missing in blocked.items() if missing}
    if blocked:
        detail = "; ".join(f"{name}: {', '.join(missing)}" for name, missing in blocked.items())
        raise RuntimeError(f"cannot render every piece, missing {detail}")
    destination.mkdir(parents=True, exist_ok=True)
    edition = {
        "schema": 1,
        "generated_by": "python3 scripts/listening_edition.py",
        "manifest_sha256": hashlib.sha256(listening.MANIFEST.read_bytes()).hexdigest(),
        "generated_with": listening.environment(),
        "mp3_bitrate": MP3_BITRATE,
        "pieces": [],
    }
    with tempfile.TemporaryDirectory(prefix="listening-edition-") as directory:
        for piece in pieces:
            workdir = Path(directory) / piece.name
            workdir.mkdir()
            output = listening.render(piece, workdir)
            report = verify(piece, entries[piece.name], output, workdir)
            wav = destination / f"{piece.name}.wav"
            mp3 = destination / f"{piece.name}.mp3"
            shutil.copyfile(output, wav)
            encode_mp3(wav, mp3, piece.name)
            readme = piece.entry.parent.parent / "README.md"
            edition["pieces"].append({
                "name": piece.name,
                "status": piece.status,
                "focus": piece.focus,
                "readme": str(readme.relative_to(listening.ROOT)) if readme.is_file() else None,
                "wav": wav.name, "wav_sha256": listening.sha256_of(wav), "wav_bytes": wav.stat().st_size,
                "mp3": mp3.name, "mp3_sha256": listening.sha256_of(mp3), "mp3_bytes": mp3.stat().st_size,
                **report,
            })
            print(f"{piece.name}: {report['duration_seconds']}s, peak {report['peak_dbfs']} dBFS, "
                  f"{'audio identical to manifest' if report['audio_identical_to_manifest'] else 'levels within the manifest tolerance'}")
    (destination / "edition.json").write_text(json.dumps(edition, indent=2, ensure_ascii=False) + "\n")
    return edition


def release_notes(edition: dict, tag: str | None = None, page_url: str | None = None) -> str:
    """Markdown for the release; with a tag the table links the assets of that release."""
    def asset(name: str) -> str:
        return f"[{name}]({REPOSITORY}/releases/download/{tag}/{name})" if tag else f"`{name}`"
    lines = ["The audio that `manifest.json` describes, rendered by CI and encoded as MP3 (256 kbit/s).",
             "Each file was rendered fresh and checked against the manifest's score hash, duration and per-second levels before upload;",
             "`edition.json` carries the hashes.", ""]
    if page_url:
        lines += [f"Listen in the browser: {page_url}", ""]
    lines += ["| Piece | Status | Length | Audio | Listen | Download |", "|---|---|---|---|---|---|"]
    for piece in edition["pieces"]:
        minutes, seconds = divmod(int(round(piece["duration_seconds"])), 60)
        identical = "byte-identical to the manifest" if piece["audio_identical_to_manifest"] else (
            "varies between renders by design" if not piece["reproducible"] else "same levels, other CPU class")
        lines.append(f"| `{piece['name']}` | {piece['status']} | {minutes}:{seconds:02d} | {identical} "
                     f"| {asset(piece['mp3'])} | {asset(piece['wav'])} |")
    env = edition["generated_with"]
    sclang = re.sub(r"\s*\(Built from.*?\)", "", env.get("sclang") or "sclang")
    lines += ["", f"Rendered with {sclang} on {env.get('os')} ({env.get('cpu')})."]
    return "\n".join(lines) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--output", type=Path, default=listening.ROOT / "renders" / "edition")
    parser.add_argument("--notes", type=Path, help="also write release notes in Markdown to this path")
    parser.add_argument("--tag", help="the release tag the notes belong to; the notes then link its assets")
    parser.add_argument("--page-url", help="the listening page, named in the notes when given")
    args = parser.parse_args()
    try:
        edition = build(args.output)
    except (OSError, RuntimeError, ValueError) as error:
        print(f"Listening edition failed: {error}", file=sys.stderr)
        return 1
    if args.notes:
        args.notes.write_text(release_notes(edition, args.tag, args.page_url))
    print(f"wrote {args.output / 'edition.json'} with {len(edition['pieces'])} pieces")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
