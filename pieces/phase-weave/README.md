# phase-weave

Two plucked strings agree on a small figure, drift into separate pulses, and
find each other again. A quiet open fifth remains after the repeated figure ends.

## System

A finite 72-second composition for two instances of the shared physical string
engine. The left loop keeps its clock. The right loop gradually moves as much as
1.5 seconds behind it, rests at that displacement, then catches up. Both loops
keep the same eight-step pattern throughout: six pitches and two rests.

The score is built synchronously in `src/score.scd`. It contains its SynthDefs
and timed events and can be rendered without an audio device. Loading the source
alone does not boot a server or start playback.

## Sound mapping

- The fixed pitch vocabulary is A3, C4, E4, G4, and A4; the loop order is
  A3–E4–A4–rest–G4–E4–rest–C4.
- Each step is 0.375 seconds on the left. A smooth displacement of the right
  onsets creates changing cross-rhythms while preserving note order.
- Left and right sit at opposite, moderate stereo positions. A small difference
  in string damping makes them distinguishable when their onsets coincide.
- Accents stay attached to the same pattern steps. The overall level grows
  toward the displaced middle, then softens as the loops converge.
- Two whole-phrase gaps reveal the strings' decay. A gentle room connects the
  notes; after the final answer it decays and fades into over two seconds of
  actual silence.

| Approximate time | Form |
|---|---|
| 0–2 s | Silence before the first shared onset |
| 2–8 s | Two strings establish the same pulse |
| 8–27 s | The right loop gradually falls behind; a phrase breath near 17 s |
| 27–35 s | A half-loop displacement holds the cross-rhythm |
| 35–55 s | The strings catch up; a second phrase breath near 38 s |
| 55–59 s | The common pulse returns, quieter and more resonant |
| 60–64 s | An open fifth and a final high answer leave a residue |
| 64–72 s | Room decay, gentle release, then silence |

The phrase gaps follow the left clock; the right voice can ring or answer across
their edges. These are musical transitions, not hard edits.

## Listening question

When do two versions of the same figure become a third rhythm? Can you keep
hearing the original pulse through the displacement, and does reunion sound like
resolution or like the loss of a richer pattern?

## Render and listen

Requires Python 3 and SuperCollider (`sclang` and `scsynth`). Only stock
SuperCollider UGens are used; no audio device or additional plugins are needed.
From this piece's directory:

```bash
bash start.sh
```

The shared renderer writes the listening file under `renders/` in this piece.
The schedule, pitches, and controls are fixed. The string excitation uses white
noise, so repeated renders can differ slightly in waveform and timbre.
Generated audio and OSC files remain outside version control.
