# the-weaving-sound

```
from the digital abyss, algorithmic threads emerge —
weaving lamentation into architecture,
silence into braided noise,
chaos into a grammar only machines remember.
```

---

## Overview

**the-weaving-sound** is a project at the intersection of generative sound synthesis and algorithmic composition — written in [SuperCollider](https://supercollider.github.io/).

It consists of two parts:

| Directory | What it is |
|---|---|
| [`the-weaving-sound/`](the-weaving-sound/) | The main work — an infinite, generative audio installation that never repeats. A state machine (*the Conductor*) breathes through five phases (Void → Emergence → Weaving → Chaos → Collapse) over hours of continuous output. |
| [`sketch/`](sketch/) | Standalone sketches and tracks — experiments, prototypes, and studies that emerged around the project. |

---

## Sketches

The `sketch/` directory contains standalone SuperCollider files — each a self-contained track or experiment:

| File | Description | BPM |
|---|---|---|
| `sc_first.scd` | First steps: acid bassline, kick, hi-hat, snare, pad — a modular techno toolkit for manual assembly (Pdef-based). | 135 |
| `sc_sec_tp.scd` | Dub-techno study with vinyl atmosphere, ghost pads, deep kick, sub-bass, dub chords, and rimshot. Fully arranged, self-running track. | 118 |
| `sc_3_track1.scd` | Extension of the dub study with a melancholic `tearPluck` melody in C minor. Includes breakdown and outro. | 118 |
| `sc_3_track2.scd` | *"Kernel Panic"* — breakbeat track with Reese bass, FM hi-hats, glass pad, and a hard drop. | 140 |
| `sc_3_track3.scd` | *"Daemon"* — minimal techno with rolling bass, arpeggio data stream (ping-pong delay), and polyrhythmic bassline mutation. | 125 |
| `sc_4_betonmembran.scd` | *"Betonmembran"* — industrial hall study: concrete sub-pressure, steel resonance, electrical arc dust, and an atonal infrastructure grid. | 118 |
| `sc_5_index_of_almost.scd` | *"Index of Almost"* — intimate generative study of unstable choice: hovering tones, interrupted pulses, formant traces, and self-erasing rhythmic gates. | 96 |

Each file can be opened and evaluated directly in SuperCollider — no external setup required.

---

## Dependencies

### Required

| Software | Arch Linux | Ubuntu / Debian | macOS |
|---|---|---|---|
| **SuperCollider** ≥ 3.12 | `sudo pacman -S supercollider` | `sudo apt install supercollider` | `brew install supercollider` |
| **sc3-plugins** | `sudo pacman -S sc3-plugins` | `sudo apt install sc3-plugins` | [GitHub Releases](https://github.com/supercollider/sc3-plugins/releases) |

> **sc3-plugins is mandatory.** The `LorenzL` UGen (chaotic oscillator) lives there.

### Recommended (Arch / PipeWire)

```bash
# Low-latency PipeWire quantum (256 frames ≈ 5.3 ms at 48 kHz)
# Add to /etc/pipewire/pipewire.conf.d/99-lowlatency.conf:
context.properties = {
    default.clock.quantum     = 256
    default.clock.min-quantum = 128
}

# Real-time privileges — add your user to the 'realtime' group:
sudo usermod -aG realtime $USER
# Then log out and back in.
```

---

## Getting Started

### The Main Work (headless, recommended)

```bash
git clone https://github.com/frnkptrln/the-weaving-sound.git
cd the-weaving-sound/the-weaving-sound
chmod +x start.sh
./start.sh
```

Press `Ctrl+C` to stop. The piece runs indefinitely — leave it overnight.

See the [main work README](the-weaving-sound/README.md) for IDE instructions, signal flow, and technical details.

### Running Sketches

Open any `.scd` file from `sketch/` in the SuperCollider IDE, boot the server, select all and evaluate. The tracks start and stop themselves.

---

## Repository Structure

```
the-weaving-sound/
├── README.md                       ← You are here
├── LICENSE
├── sketch/                         ← Standalone sketches & tracks
│   ├── sc_first.scd                   Acid techno toolkit (135 BPM)
│   ├── sc_sec_tp.scd                  Dub-techno study (118 BPM)
│   ├── sc_3_track1.scd                Dub + melody (118 BPM)
│   ├── sc_3_track2.scd                "Kernel Panic" breakbeat (140 BPM)
│   ├── sc_3_track3.scd                "Daemon" minimal techno (125 BPM)
│   ├── sc_4_betonmembran.scd          "Betonmembran" hall study (118 BPM)
│   └── sc_5_index_of_almost.scd       "Index of Almost" generative study (96 BPM)
└── the-weaving-sound/              ← The generative main work
    ├── README.md                      Technical deep-dive
    ├── start.sh                       Headless launcher (bash)
    └── src/
        ├── main.scd                   Master boot process
        ├── 01_synthdefs.scd           All SynthDef definitions (6 voices + FX)
        ├── 02_fx_routing.scd          FX SynthDef, bus/group setup, ~startFxRouting
        └── 03_weaver_logic.scd        Generative conductor, ~startWeaver
```

---

## License

Released into the sound under the **MIT License**.  
Use it. Break it. Let it run for 72 hours unattended. That is what it was made for.

---

*"The loom does not know it is weaving. That is its only freedom."*
