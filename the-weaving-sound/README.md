# the-weaving-sound — The Main Work

An infinite, generative audio installation that never repeats.

---

## The Conductor

At its core is a **state machine** — *the Conductor* — that breathes through five phases over hours of continuous output:

| Phase | Character | Duration |
|---|---|---|
| **VOID** | Near-silence. A sub-bass drone breathes. A single plucked string surfaces, then disappears. | 1.5 – 4 min |
| **EMERGENCE** | A granular mist rises from the bass floor. Sparse melodies gain frequency. Proto-glitches appear. | 1 – 2 min |
| **WEAVING** | The loom is in full motion. A dub-techno pulse emerges off the grid. All voices speak simultaneously. Chaos glitches spray in clusters. | 2 – 5 min |
| **CHAOS** | The Lorenz attractor breaks free. Rapid-fire glitch walls. The pulse accelerates. Time distorts. | 30 sec – 1.5 min |
| **COLLAPSE** | One by one, every thread dissolves. The sound reclaims its silence. | 30 – 60 sec |

---

## Sonic DNA

- **Sub-bass drone** — multi-partial sine bed with slow formant animation (Resonz filters modulated by LFNoise2)
- **Karplus-Strong strings** — physical-model plucks as sparse melodic events; pitch drawn from an A-minor modal vocabulary
- **Granular cloud** — GrainNoise with per-grain pan randomisation; band-pass centre-frequency swept by nested LFOs
- **Lorenz chaos glitches** — the classic strange attractor (σ=10, ρ=28, β=8/3) maps its output to frequency, producing unrepeatable micro-events
- **Dub-techno pulse** — pitch-envelope kick with transient click; pattern humanised via micro-timing offsets of ±0.9%
- **Shimmer pad** — six detuned sine partials with independent amplitude LFOs
- **Master FX chain** — tape-delay (CombC with wow/flutter LFO → LPF tape-softening) feeding FreeVerb2 (room ≈ 0.93), followed by soft tanh saturation and a brickwall limiter

---

## Signal Flow

```
[void_drone]  ──┐
[void_pad]    ──┤
[void_pulse]  ──┼──► ~sendBus (Bus.audio stereo) ──► [fx_master] ──► Hardware Out
[thread_pluck]──┤         (all sources write here)    tape-delay
[chaos_glitch]──┤                                     + reverb
[gran_cloud]  ──┘                                     + limiter
```

---

## Running

### Method 1 — Terminal (headless, recommended)

```bash
chmod +x start.sh
./start.sh
```

Press `Ctrl+C` to stop. The piece runs indefinitely — leave it overnight.

### Method 2 — SuperCollider IDE

1. Open `src/main.scd` in the SuperCollider IDE (scide).
2. Boot the server: **Language → Boot Server** (or `Ctrl+B`).
3. Select all (`Ctrl+A`) and evaluate (`Ctrl+Enter`).

---

## Source Files

```
the-weaving-sound/
├── README.md               ← You are here
├── start.sh                ← Headless launcher (bash)
└── src/
    ├── main.scd            ← Master boot process
    ├── 01_synthdefs.scd    ← All SynthDef definitions (6 voices + FX)
    ├── 02_fx_routing.scd   ← FX SynthDef, bus/group setup, ~startFxRouting
    └── 03_weaver_logic.scd ← Generative conductor, ~startWeaver
```

---

## Technical Notes

- The master FX synth is instantiated in the `~fxGroup` (which is ordered *after* `~sourceGroup`), guaranteeing sources always render before effects in the scsynth node tree.
- All `.wait` calls in the generative logic execute inside Routines on `TempoClock.default` — never in raw sclang evaluation order.
- `s.sync` is called at each critical transition in `main.scd` to prevent race conditions between SynthDef compilation and Synth instantiation.
- Gate-sustained synths (`void_drone`, `void_pad`, `granular_cloud`) are released gracefully via `gate: 0`, allowing their ASR envelopes to complete before `doneAction: 2` frees the node.
- Server memory is pre-allocated to 64 MB (`s.options.memSize = 65536`) to accommodate the granular engine's internal buffers.
