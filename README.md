# the-weaving-sound

```
from the digital abyss, algorithmic threads emerge —
weaving lamentation into architecture,
silence into braided noise,
chaos into a grammar only machines remember.
```

---

## Overview

**the-weaving-sound** is structured as an **anthology of generative sound pieces**: multiple experiments, multiple conductors, one shared sonic language. Most pieces use SuperCollider; deterministic offline renderers can join the collection when the form calls for a fixed recording or a different synthesis process.

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

---

## Getting Started

### Run the classic piece

```bash
cd pieces/weaving-classic
chmod +x start.sh
./start.sh
```

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

---

## Dependencies

| Software | Arch Linux | Ubuntu / Debian | macOS |
|---|---|---|---|
| **SuperCollider** ≥ 3.12 | `sudo pacman -S supercollider` | `sudo apt install supercollider` | `brew install supercollider` |
| **sc3-plugins** | `sudo pacman -S sc3-plugins` | `sudo apt install sc3-plugins` | [GitHub Releases](https://github.com/supercollider/sc3-plugins/releases) |

> **sc3-plugins is mandatory** for several UGens used by the project family. The Python-based `rooms-change-us` piece documents its own additional dependencies.

---

## License

Released into the sound under the **MIT License**.

---

*"The loom does not know it is weaving. That is its only freedom."*
