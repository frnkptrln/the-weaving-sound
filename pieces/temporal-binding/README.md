# temporal-binding

## System

Five pitches move between simultaneous and sequential presentation. Their order,
level, and timbre stay fixed so that the changing onset gaps remain audible. The
interactive study runs indefinitely; the offline version follows a finite return
from chord to arpeggio to chord.

## Sound mapping

- `motion` opens the onset gap; at zero, all five notes begin together.
- `density` shortens both the onset gaps and the pause between phrases.
- `space` lengthens the hold/release and widens the stereo field.
- `brightness`, `grit`, and `tension` shape the shared subtractive voice.

The mapping lives in `src/study.scd` and is shared by live playback and rendering.
Timing uses seconds and is independent of other pieces' tempo settings. Macro
values are clipped to 0..1 when each phrase begins.

## Listening question

At what point does one harmonic object become a sequence of separate events?
Does that boundary remain in the same place when motion, density, or space changes?
Does the return to a chord feel like the reverse of its separation?

## Listen without an audio device

Requires SuperCollider (`sclang` and `scsynth`); no additional plugins are needed.
From this piece's directory:

```bash
bash render.sh
```

This writes `renders/temporal-binding.wav`: approximately 64 seconds, 48 kHz,
stereo, 24-bit PCM. The event schedule is fixed; the voice contains white noise,
so separate renders are not guaranteed to be sample-identical. Generated audio
and the OSC score remain outside version control.

| Time | Motion |
|---|---|
| 0–6 s | Held chord presentation |
| 6–24 s | Onsets gradually separate |
| 24–32 s | Arpeggiated presentation |
| 32–50 s | Onsets gather together again |
| 50–56 s | Chord returns |
| 56–64 s | Final voices release into silence |

The motion curve is sampled at each phrase boundary, so these are approximate
transitions, not hard edits. The engine may append one final audio block.

Optional MP3 copy:

```bash
ffmpeg -i renders/temporal-binding.wav -codec:a libmp3lame -b:a 256k renders/temporal-binding.mp3
```

## Play interactively

Run `bash start.sh`, or evaluate `src/main.scd` in the SuperCollider IDE.
Change `~macros[\motion] = 0.75;` while it plays; changes take effect at the next
phrase. Evaluate `~temporalBindingStop.();` to stop new notes and release the
remaining voices. Evaluating `src/main.scd` again replaces the previous routine.
Use Ctrl+C to close a terminal session.
