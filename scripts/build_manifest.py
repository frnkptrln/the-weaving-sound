#!/usr/bin/env python3
"""Render every piece twice and write manifest.json from the repository and the results.

Usage: python3 scripts/build_manifest.py [--output manifest.json]
Requires the renderers' own tools: sclang and scsynth for the SuperCollider
pieces, and espeak plus the packages in pieces/rooms-change-us/requirements.txt
for rooms-change-us. Interactive pieces are listed without a render.

A piece counts as reproducible when both renders produce identical audio. Only
then is its audio hash recorded; otherwise the manifest keeps the OSC score hash
(when the renderer writes one) and the measured levels, so tests/test_listening.py
can still detect drift.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import sys
import tempfile

sys.path.insert(0, str(Path(__file__).resolve().parent))
import listening  # noqa: E402

SCHEMA = 1


def render_entry(piece: listening.Piece, workdir: Path) -> dict:
    """Render twice, measure both, and describe what is stable."""
    measurements, score_hashes = [], []
    for attempt in (1, 2):
        directory = workdir / f"{piece.name}-{attempt}"
        directory.mkdir()
        output = listening.render(piece, directory)
        measurements.append(listening.measure(output))
        score = listening.score_path(piece, output)
        score_hashes.append(listening.sha256_of(score) if score else None)
    first, second = measurements
    reproducible = first.pcm_sha256 == second.pcm_sha256
    if score_hashes[0] != score_hashes[1]:
        raise RuntimeError(f"{piece.name}: the OSC score itself differs between renders")
    for field in ("sample_rate", "channels", "bits", "duration_seconds"):
        if getattr(first, field) != getattr(second, field):
            raise RuntimeError(f"{piece.name}: {field} differs between renders")
    return {
        "sample_rate": first.sample_rate,
        "channels": first.channels,
        "bits": first.bits,
        "duration_seconds": first.duration_seconds,
        "peak_dbfs": max(first.peak_dbfs, second.peak_dbfs),
        "rms_dbfs": round((first.rms_dbfs + second.rms_dbfs) / 2, 2),
        "tail_peak_dbfs": max(first.tail_peak_dbfs, second.tail_peak_dbfs),
        "reproducible": reproducible,
        "pcm_sha256": first.pcm_sha256 if reproducible else None,
        "score_sha256": score_hashes[0],
        "renders_compared": 2,
        # Per second: RMS per channel, then peak per channel, in dBFS, from the
        # first render; and how far the second render strayed from it.
        "seconds_columns": ["rms_left", "rms_right", "peak_left", "peak_right"],
        "seconds": [list(row) for row in first.seconds],
        "seconds_max_deviation_db": round(
            listening.fingerprint_deviation(first.seconds, second.seconds), 3),
    }


def build() -> dict:
    pieces = listening.discover()
    blocked = {piece.name: listening.missing_requirements(piece)
               for piece in pieces if piece.renderable}
    blocked = {name: missing for name, missing in blocked.items() if missing}
    if blocked:
        detail = "; ".join(f"{name}: {', '.join(missing)}" for name, missing in blocked.items())
        raise RuntimeError(f"cannot render every piece, missing {detail}")
    entries = []
    with tempfile.TemporaryDirectory(prefix="weaving-manifest-") as directory:
        for piece in pieces:
            entry = listening.static_entry(piece)
            entry["render"] = render_entry(piece, Path(directory)) if piece.renderable else None
            entries.append(entry)
            state = entry["render"]
            if state is None:
                print(f"{piece.name}: interactive, no offline render")
            else:
                print(f"{piece.name}: {state['duration_seconds']}s, {state['channels']} ch, "
                      f"peak {state['peak_dbfs']} dBFS, rms {state['rms_dbfs']} dBFS, "
                      f"{'reproducible' if state['reproducible'] else 'audio varies between renders'}")
    return {
        "schema": SCHEMA,
        "generated_by": "python3 scripts/build_manifest.py",
        "generated_with": listening.environment(),
        "pieces": entries,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--output", type=Path, default=listening.MANIFEST)
    args = parser.parse_args()
    try:
        manifest = build()
    except (OSError, RuntimeError, ValueError) as error:
        print(f"Manifest build failed: {error}", file=sys.stderr)
        return 1
    args.output.write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n")
    print(f"wrote {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
