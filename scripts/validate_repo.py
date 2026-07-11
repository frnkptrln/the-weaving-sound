#!/usr/bin/env python3
"""Static repository checks that do not require SuperCollider."""
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
REQUIRED_DOC_SECTIONS = ("## System", "## Sound mapping", "## Listening question")

def main() -> int:
    failures: list[str] = []
    pieces = sorted((ROOT / "pieces").iterdir())
    for piece in pieces:
        if not piece.is_dir():
            continue
        for relative in ("README.md", "start.sh", "src/main.scd"):
            if not (piece / relative).is_file():
                failures.append(f"{piece.name}: missing {relative}")
        launcher = piece / "start.sh"
        if launcher.is_file():
            text = launcher.read_text()
            if "BASH_SOURCE[0]" not in text:
                failures.append(f"{piece.name}: launcher is not location-independent")

    temporal_readme = (ROOT / "pieces/temporal-binding/README.md").read_text()
    for section in REQUIRED_DOC_SECTIONS:
        if section not in temporal_readme:
            failures.append(f"temporal-binding: missing {section}")
    for relative in ("core/macros.scd", "core/metadata.scd"):
        if not (ROOT / relative).is_file():
            failures.append(f"missing shared contract {relative}")

    if failures:
        print("repository validation failed:", file=sys.stderr)
        for failure in failures:
            print(f"- {failure}", file=sys.stderr)
        return 1
    print(f"repository validation passed ({len(pieces)} pieces)")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
