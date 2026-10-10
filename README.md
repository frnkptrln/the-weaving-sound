# the-weaving-sound

```
from the digital abyss, algorithmic threads emerge —
weaving lamentation into architecture,
silence into braided noise,
chaos into a grammar only machines remember.
```

---

## Overview

**the-weaving-sound** is an **anthology of generative sound pieces**: multiple experiments, multiple conductors, one shared sonic language. Most pieces use [SuperCollider](https://supercollider.github.io/); deterministic offline renderers can join the collection when the form calls for a fixed recording or a different synthesis process.

The repository asks how systems become audible. Each curated piece connects a
small generative mechanism to a perceptual question rather than merely presenting
a synthesis technique.

---

## Listen

The finite pieces are published as a **[listening edition](https://github.com/frnkptrln/the-weaving-sound/releases/latest)**:
one MP3 (and the WAV it was encoded from) per renderable piece, rendered by CI
on the manifest's toolchain and checked against `manifest.json` before upload.
`edition.json` in the release carries the score and audio hashes, so a listener
can tell that the file is the recorded audio and not a variant. Interactive
pieces (`weaving-classic`, the synthesis labs) remain SuperCollider sessions.

The edition also has a page: `scripts/build_site.py` writes `site/index.html`
from `manifest.json` and the pieces' READMEs — one player per finite piece,
the sessions listed below them, no scripts, no fonts, no tracking. The
`listening page` workflow builds it on every change and deploys it with GitHub
Pages once Pages is enabled for the repository (source: GitHub Actions). For
listening offline, point it at a local edition:

```bash
python3 scripts/listening_edition.py --output renders/edition   # needs the render toolchain
python3 scripts/build_site.py --audio-base ../renders/edition/  # then open site/index.html
```

---

## Repository Layout

| Directory | Role |
|---|---|
| [`pieces/`](pieces/) | Curated, runnable works (each with own `README.md`, `start.sh`, `src/`) |
| [`sketches/`](sketches/) | Raw studies, prototypes, and drafts |
| [`engines/`](engines/) | Shared synthesizer engines and sound-building modules |
| [`core/`](core/) | Shared runtime contracts (macros, routing, lifecycle) |

---

## Pieces

| Piece | Focus | Status |
|---|---|---|
| [`pieces/weaving-classic/`](pieces/weaving-classic/) | Original long-form conductor work (Void → Emergence → Weaving → Chaos → Collapse) | Active |
| [`pieces/subtractive-lab/`](pieces/subtractive-lab/) | Subtraktive Synthese Demo | Active |
| [`pieces/fm-pressure/`](pieces/fm-pressure/) | FM-Synthese Demo | Active |
| [`pieces/digital-lab/`](pieces/digital-lab/) | Digitale Klangsynthese Demo | Active |
| [`pieces/physical-lab/`](pieces/physical-lab/) | Physical Modelling Demo | Active |
| [`pieces/software-synth-lab/`](pieces/software-synth-lab/) | Software-Synthesizer Demo | Active |
| [`pieces/granular-drift/`](pieces/granular-drift/) | Granular-Synthese Demo | Active |
| [`pieces/temporal-binding/`](pieces/temporal-binding/) | Chord ↔ arpeggio; interactive study and 64-second offline render | Study |
| [`pieces/phase-weave/`](pieces/phase-weave/) | 72-second string loops: shared pulse, displacement, reunion | Study |
| [`pieces/spectral-memory/`](pieces/spectral-memory/) | 80-second chime: harmonic object, metallic fragments, altered return | Active |
| [`pieces/rooms-change-us/`](pieces/rooms-change-us/) | 92-second procedural sound room with unstable pulse, processed voice, and complete fade | Active |

---

## Synthesizer Expansion Plan

To reflect different ways of building sound (aligned with common synth learning categories such as subtractive, FM, digital/wavetable, physical modeling, and granular), the shared engine roadmap is:

1. **Subtractive**
   - Oscillator stacks (saw/pulse/noise)
   - Filter contour macros (`brightness`, `tension`)
2. **FM**
   - 2–6 operator templates
   - Ratio/index morphing macros (`motion`, `grit`)
3. **Digital / Wavetable**
   - Timbral table scanning
   - Spectral interpolation controls
4. **Physical Modeling**
   - Karplus-style plucks/strings
   - Damping/body material controls
5. **Granular**
   - Grain cloud and density layers
   - Position/size/jitter controls
6. **Hybrid**
   - Cross-engine morph scenes
   - Unified macro automation over multiple engines

### Consistency Contracts

Across all pieces and conductors:

- **Macro contract** (0..1): `brightness`, `density`, `motion`, `space`, `grit`, `tension`
- **Lifecycle contract**: `init()`, `start()`, `stop()`, `free()`
- **Routing contract**: sources → shared send bus → master FX
- **Metadata contract**: piece name, BPM range, tags, engines, mode

This keeps experiments diverse while preserving compatibility and maintainability.

The macro and metadata contracts are executable in [`core/`](core/).
`temporal-binding` uses both directly. Shared lifecycle and routing helpers remain
planned; the classic piece currently owns its routing and conductor lifecycle.

---

## Getting Started

### Run the classic piece

```bash
cd pieces/weaving-classic
chmod +x start.sh
./start.sh
```

### Render temporal-binding

```bash
bash pieces/temporal-binding/render.sh
```

Creates a 64-second stereo WAV in `pieces/temporal-binding/renders/`. This uses
SuperCollider's offline renderer and needs no audio device or sc3-plugins.
See the [listening study](pieces/temporal-binding/) for its form and live controls.

### Render phase-weave and spectral-memory

```bash
python3 scripts/render_piece.py phase-weave spectral-memory
```

These two complete compositions use stock SuperCollider synthesis and need no
audio device. The shared renderer writes a 48 kHz stereo, 24-bit WAV into each
piece's `renders/` directory, plus MP3 when `ffmpeg` is installed. It also saves
the exact OSC score and a JSON report with duration, levels, and the score hash.
Floating-point audio is checked for invalid samples, over-range peaks, and a
silent final second before conversion to the delivery format. Existing render
files are replaced only after the new run passes its checks.

For a single destination, append `--output-dir /path/to/listening-folder`.
Python 3.10+ is required; no third-party Python packages are needed.

### Render rooms-change-us

```bash
cd pieces/rooms-change-us
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
bash start.sh
```

### Open sketches

Open any `.scd` from `sketches/` in SuperCollider IDE, boot server, evaluate all.

[`Lantern field`](sketches/lantern-field/) is a separate 96-second offline sketch:
six chime clocks gradually find and lose a shared pulse. It uses Python/NumPy
and includes an uncoupled listening reference, an onset score and numeric render
checks. It awaits listening review before joining the curated pieces.

[`A place left for you`](sketches/a-place-left-for-you/) is a 132-second sketch:
three voices inherit a five-note contour, share it, and leave their echoes
behind. A memory-off reference uses the same score and gain. Both versions
render offline with Python/NumPy; they remain sketches awaiting listening review.

### Validate the repository

```bash
python scripts/validate_repo.py
python -m unittest discover -s tests -v
for script in pieces/*/*.sh; do bash -n "$script" || exit; done
```

### Listening test and render manifest

[`manifest.json`](manifest.json) lists every piece with its status, render
command, documented duration, the sources its renderer loads, and, for each
offline render, the sample rate, channel count, measured duration, levels, and
a content hash. It is generated, not written by hand:

```bash
python3 scripts/build_manifest.py
```

This renders each finite piece twice. When both renders are identical the
audio hash is recorded; when they differ (unseeded noise in a shared engine),
the manifest keeps the OSC score hash and the measured levels instead and says
so. The listening test renders every piece again and checks the result against
the manifest:

```bash
python -m unittest -v tests.test_listening
```

Each piece gets one test: stereo, documented duration, not silent, no
clipping, an ending in silence, and a matching hash (or, for varying audio,
levels within tolerance and a matching score hash). The manifest also keeps
per-second levels for every render. Interactive pieces without an offline
render path are skipped and say so, as are pieces whose renderer's tools are
missing. Rerun the manifest build after an intended change so the test records
the new hash. `rooms-change-us` needs `espeak` and its exactly pinned Python
packages; the SuperCollider pieces need `sclang` and `scsynth`. The test runs
each piece's own render command, so temporal-binding and rooms-change-us
write into their untracked `renders/` directories as they always do.

Audio hashes have a scope. scsynth renders reproduced their hashes on every
machine tried, so theirs must match everywhere. NumPy renders differ in their
last bits between CPU SIMD classes (AVX2 versus AVX-512, for instance), so the
manifest records the class it was built on; on the same class the hash must
match, on another the per-second levels must agree within 0.1 dB. A mismatch
is reported together with both environments.

[`docs/study-to-piece.md`](docs/study-to-piece.md) proposes what separates a
study from a piece here, and what a piece needs before it is exported as MP3.

For language compilation, macro checks, and actual synthesis without an audio
device, install SuperCollider and sc3-plugins, then run:

```bash
python3 scripts/validate_audio.py
# Optional: retain the short WAVs and logs for inspection.
python3 scripts/validate_audio.py --keep-renders renders/audio-validation
```

The audio checks compile curated SuperCollider files and render each shared and
classic voice plus the master FX. They check stereo routing, finite samples,
headroom, and release tails. CI also renders phase-weave and spectral-memory in
full, validates their resulting audio, and runs the listening test above for
every piece with an offline render. The checks are bounded; they do not
exercise the classic conductor's hours-long form or the interactive controls on a
real audio device.

---

## Dependencies

| Software | Arch Linux | Ubuntu / Debian | macOS |
|---|---|---|---|
| **SuperCollider** ≥ 3.12 | `sudo pacman -S supercollider` | `sudo apt install supercollider` | `brew install supercollider` |
| **sc3-plugins** | `sudo pacman -S sc3-plugins` | `sudo apt install sc3-plugins` | [GitHub Releases](https://github.com/supercollider/sc3-plugins/releases) |

> **sc3-plugins is required for `digital-lab`** (`Decimator`) and the complete audio validation. `weaving-classic`, `temporal-binding`, `phase-weave`, and `spectral-memory` use standard SuperCollider UGens. The Python-based `rooms-change-us` piece documents its own additional dependencies.

---

## License

Released into the sound under the **MIT License**.

---

*"The loom does not know it is weaving. That is its only freedom."*
