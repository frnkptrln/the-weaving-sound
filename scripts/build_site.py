#!/usr/bin/env python3
"""Write the listening page: one static HTML file that plays the listening edition.

The page is generated from manifest.json and the pieces' READMEs, so it says
exactly what the manifest says — which pieces have a finite render, how long
they are, whether a render is reproducible — and plays the MP3s of the latest
listening edition release. It uses no scripts, no fonts and no tracking; the
only network requests are the audio files themselves.

Usage:
  python3 scripts/build_site.py                       # site/index.html, audio from the latest release
  python3 scripts/build_site.py --audio-base ../renders/edition/   # a local edition, for listening offline
"""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import html
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "manifest.json"
REPOSITORY = "https://github.com/frnkptrln/the-weaving-sound"
RELEASE_AUDIO = f"{REPOSITORY}/releases/latest/download/"

STYLE = """
:root { color-scheme: light dark; --ink: #1d1d1b; --paper: #f6f4ef; --muted: #6b665c; --line: #d8d3c8; --accent: #7a4b1e; }
@media (prefers-color-scheme: dark) { :root { --ink: #e8e4db; --paper: #16161a; --muted: #9a958a; --line: #34343a; --accent: #d9a46a; } }
html { background: var(--paper); color: var(--ink); font: 17px/1.55 ui-serif, Georgia, "Times New Roman", serif; }
body { margin: 0 auto; max-width: 42rem; padding: 3rem 1.25rem 4rem; }
h1 { font-size: 1.6rem; font-weight: normal; letter-spacing: .01em; margin: 0 0 .25rem; }
h1 small, .meta, footer, .sessions li span { color: var(--muted); font: 14px/1.5 ui-monospace, Menlo, Consolas, monospace; }
h2 { font-size: 1.15rem; font-weight: normal; margin: 2.75rem 0 .2rem; }
h2 a { color: inherit; text-decoration: none; border-bottom: 1px solid var(--line); }
p { margin: .6rem 0; }
blockquote { margin: .6rem 0 .6rem 1.2rem; font-style: italic; }
a { color: var(--accent); }
audio { display: block; width: 100%; margin: .9rem 0 .4rem; }
.files { font: 14px/1.5 ui-monospace, Menlo, Consolas, monospace; }
.files a + a::before { content: " · "; color: var(--muted); }
section + section { border-top: 1px solid var(--line); }
.sessions { padding-left: 1.2rem; }
.sessions li { margin: .3rem 0; }
footer { margin-top: 3.5rem; border-top: 1px solid var(--line); padding-top: 1rem; }
"""


def first_paragraph(readme: Path) -> tuple[str, str]:
    """The first prose paragraph of a README, and the block quote that follows it, if any."""
    lines = readme.read_text(encoding="utf-8").splitlines()
    paragraph: list[str] = []
    index = 0
    for index, line in enumerate(lines):
        stripped = line.strip()
        if not stripped or stripped.startswith(("#", ">", "```", "|", "-", "*", "!")):
            if paragraph:
                break
            continue
        paragraph.append(stripped)
    quote: list[str] = []
    for line in lines[index:]:
        stripped = line.strip()
        if stripped.startswith(">"):
            quote.append(stripped.lstrip("> ").strip())
        elif stripped and quote:
            break
    return " ".join(paragraph), " ".join(quote)


def duration_label(seconds: float) -> str:
    minutes, rest = divmod(int(round(seconds)), 60)
    return f"{minutes}:{rest:02d}"


def git_describe() -> str:
    try:
        return subprocess.run(["git", "rev-parse", "--short", "HEAD"], cwd=ROOT, capture_output=True,
                              text=True, check=True, timeout=10).stdout.strip()
    except (OSError, subprocess.SubprocessError):
        return "working tree"


def render_page(manifest: dict, audio_base: str, *, revision: str, now: datetime) -> str:
    e = html.escape
    rendered = [p for p in manifest["pieces"] if p.get("render")]
    rendered.sort(key=lambda p: p.get("status") != "piece")  # pieces first, studies after, manifest order within
    sessions = [p for p in manifest["pieces"] if not p.get("render")]
    out = [
        "<!doctype html>", '<html lang="en">', "<head>", '<meta charset="utf-8">',
        '<meta name="viewport" content="width=device-width, initial-scale=1">',
        "<title>the-weaving-sound — listening edition</title>",
        '<meta name="description" content="The finite pieces of the anthology, rendered by CI and checked against the manifest.">',
        f"<style>{STYLE}</style>", "</head>", "<body>", "<header>",
        f'<h1>the-weaving-sound <small>listening edition · {len(rendered)} pieces</small></h1>',
        "<p>The finite pieces of the anthology, as audio. Every file was rendered by CI on the "
        "manifest's toolchain and checked against <code>manifest.json</code> — score hash, duration, "
        "per-second levels — before it was published; <code>edition.json</code> in the "
        f'<a href="{e(REPOSITORY)}/releases/latest">release</a> carries the hashes, so a listener can '
        "tell that a file is the recorded audio and not a variant.</p>",
        "</header>", "<main>",
    ]
    for piece in rendered:
        name, render = piece["name"], piece["render"]
        readme = ROOT / "pieces" / name / "README.md"
        description, quote = first_paragraph(readme) if readme.is_file() else (piece.get("focus", ""), "")
        repro = "reproducible render" if render.get("reproducible") else "render varies by design"
        out += [
            "<section>",
            f'<h2><a href="{e(REPOSITORY)}/tree/main/pieces/{e(name)}/">{e(name)}</a></h2>',
            f'<p class="meta">{e(piece.get("status", ""))} · {duration_label(render["duration_seconds"])} · '
            f'{render["channels"]} ch · {render["sample_rate"]} Hz · {repro}</p>',
            f"<p>{e(description)}</p>",
            *( [f"<blockquote>{e(quote)}</blockquote>"] if quote else [] ),
            f'<audio controls preload="none" src="{e(audio_base)}{e(name)}.mp3">'
            f'Your browser does not play MP3; <a href="{e(audio_base)}{e(name)}.mp3">download the file</a>.</audio>',
            f'<p class="files"><a href="{e(audio_base)}{e(name)}.mp3">mp3</a>'
            f'<a href="{e(audio_base)}{e(name)}.wav">wav</a>'
            f'<a href="{e(REPOSITORY)}/blob/main/pieces/{e(name)}/README.md">readme</a></p>',
            "</section>",
        ]
    if sessions:
        out += [
            "<section>", "<h2>Sessions</h2>",
            "<p>These pieces are interactive or open-ended and have no finite render. They run as "
            "SuperCollider sessions from their launchers.</p>",
            '<ul class="sessions">',
        ]
        for piece in sessions:
            name = piece["name"]
            out.append(f'<li><a href="{e(REPOSITORY)}/tree/main/pieces/{e(name)}/">{e(name)}</a> '
                       f'<span>{e(piece.get("status", ""))}</span> — {e(piece.get("focus", ""))}</li>')
        out += ["</ul>", "</section>"]
    manifest_hash = hashlib.sha256(MANIFEST.read_bytes()).hexdigest()[:12]
    out += [
        "</main>", "<footer>",
        f"<p>Generated by <code>scripts/build_site.py</code> from <code>manifest.json</code> ({manifest_hash}) "
        f"at revision {e(revision)}, {now.strftime('%Y-%m-%d %H:%M UTC')}. "
        "Audio from the latest listening edition release. No scripts, no fonts, no tracking.</p>",
        f'<p><a href="{e(REPOSITORY)}">Repository</a> · <a href="{e(REPOSITORY)}/releases">All editions</a></p>',
        "</footer>", "</body>", "</html>", "",
    ]
    return "\n".join(out)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--output", type=Path, default=ROOT / "site" / "index.html")
    parser.add_argument("--audio-base", default=RELEASE_AUDIO,
                        help="URL or relative path the MP3 and WAV files are served from (default: the latest release)")
    args = parser.parse_args()
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    page = render_page(manifest, args.audio_base, revision=git_describe(), now=datetime.now(timezone.utc))
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(page, encoding="utf-8")
    rendered = sum(1 for p in manifest["pieces"] if p.get("render"))
    print(f"wrote {args.output} with {rendered} playable pieces")
    return 0


if __name__ == "__main__":
    sys.exit(main())
