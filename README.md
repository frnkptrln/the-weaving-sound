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

### Validate the repository

```bash
python scripts/validate_repo.py
python -m unittest discover -s tests -v
for script in pieces/*/*.sh; do bash -n "$script" || exit; done
```

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
full and validates their resulting audio. The checks are bounded; they do not
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
