# spectral-memory

An 80-second composition for a chime, its changing material, and the room that
remembers it. A small five-note figure returns often enough to become familiar;
its upper partials gradually move away from harmonic relationships.

## System

Six sine modes form each struck object. Its fundamental stays in place while
the upper modes move toward inharmonic ratios, with their own decay times and
slight movement. A quiet low D supports the first two sections, disappears during
the fragmented middle, and returns beneath the final recollection.

The score is finite. It embeds three local SynthDefs, uses standard SuperCollider
UGens, and needs no samples or extra plugins. Nothing boots a live audio server.

## Sound mapping

- `tension` moves upper modes from harmonic chime to metallic resonance.
- `brightness` controls the low-pass ceiling, opening during the transformation
  and closing on the return.
- Fixed pitch order, unequal spacing, and accents establish the recurring figure.
- Fragmented phrases lose their bass support and leave pauses between answers.
- Short stereo reflections and a room tail connect the gestures; the final room
  fades completely after the last pair of notes.

The piece uses the shared macro and metadata contracts. Phrase development,
note lengths, stereo positions, and room changes are composed in `src/score.scd`.

## Listening question

When does a familiar set of pitches start to sound like a different material?
After the original figure returns, do the remaining metallic partials sound like
part of the object, or like a memory of what happened to it?

## Form

| Time | Section | What changes |
|---|---|---|
| 0–18 s | Object | Three clear statements establish the chime figure and its low root. |
| 18–38 s | Alloy | The contour stays recognizable while upper modes become metallic. |
| 38–58 s | Shards | Short, scattered answers replace the figure; the low root disappears. |
| 58–80 s | Trace | The figure returns more quietly with residual inharmonicity, then fades into silence. |

Tails cross the section boundaries. The last new notes arrive at 71.5 and 72
seconds; the remaining time belongs to their release and the fading room.

## Render

Requires Python 3 and SuperCollider (`sclang` and `scsynth`). From this directory:

```bash
bash start.sh
```

Or from the repository root:

```bash
python3 scripts/render_piece.py spectral-memory
```

The shared renderer writes an 80-second stereo WAV at 48 kHz. The schedule uses
a local fixed random seed, restored after score construction. Each chime also
seeds its short noise attack. This makes the musical decisions reproducible;
bit-for-bit waveform identity across SuperCollider versions or platforms is not
guaranteed. The ending includes a complete release and a silent final interval.
