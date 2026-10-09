# From study to piece

**Status: proposal.** Nothing here is enforced yet. It describes how this
repository already uses the two words and what a piece would need before it
leaves the repository as an MP3.

## What the repository calls a study

A study exists to make one perceptual question audible. It is finished when the
question can be heard, not when the sound is finished. In this repository a
study has:

- a listening question in its README that names one boundary or transition;
- a fixed mechanism that exposes that question, usually driven by the shared
  macro contract in `core/`;
- a form that serves the question, such as the chord, separation and return in
  temporal-binding, or the displacement and reunion in phase-weave;
- `status: \study` in its metadata where it declares any, and "Study" in the
  README pieces table.

An interactive study may run indefinitely; an offline study has a finite render
so the question can be heard without a live server.

## What the repository calls a piece

A piece is a study that has been listened to as music rather than as a
demonstration. Its form is decided, its duration is fixed, and it is meant to
be heard from beginning to end by someone who does not know the question. In
this repository spectral-memory and rooms-change-us are the finite pieces; both
are marked "Active" in the README table.

The six lab pieces (subtractive-lab, fm-pressure, digital-lab, physical-lab,
software-synth-lab, granular-drift) and weaving-classic are also marked
"Active", but they are open-ended and have no offline render. Under this
proposal they would stay runnable works and would not be candidates for MP3
export until they gain a finite form.

## What a piece needs before it is exported as MP3

1. **A finite offline render.** A render command listed in `manifest.json`,
   producing stereo audio of the documented duration with no audio device.
2. **A recorded hash.** The render's audio hash, or, where the audio varies
   between renders, its OSC score hash, recorded in `manifest.json` by
   `scripts/build_manifest.py` and checked by `tests/test_listening.py`.
3. **A passing listening test.** Non-silence, no clipping, stereo, documented
   duration, and an ending in silence, all checked automatically on every push.
4. **Reproducibility decided.** Either the audio is bit-for-bit reproducible,
   or the README says which sound is generated from unseeded noise and that
   this is intended. Seeding is a one-line change in the score; whether to
   apply it is a decision about the piece, not about the test.
5. **A listening check by Frank on speakers and on headphones,** from the
   WAV the manifest describes. This is the only step no script can do. The
   MP3 is encoded from that same WAV (`ffmpeg`, 256 kbit/s, as the renderers
   already do) after the check, never from a different render.
6. **Status changed to piece** in the README table and, where declared, in the
   metadata (`status: \active`), in the same commit as the manifest update.

## What this proposal does not decide

It does not say which study should become a piece, or what any piece should
sound like. Those decisions stay with the composer.
