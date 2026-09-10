# core

Small executable contracts shared by curated pieces. They provide a common
language without forcing every work into the same composition.

## Macro contract

macros.scd defines six normalized controls in the range 0..1:

brightness, density, motion, space, grit, tension

A piece owns the mapping from those perceptual controls to synthesis parameters.
Values outside the range are clipped at the contract boundary.

## Metadata contract

metadata.scd validates a piece description with these fields:

name, description, engines, tags, mode, duration, status

Status is one of active, study, or archived.

## Finite score contract

A finite SuperCollider piece may expose `src/score.scd` in place of a live
`src/main.scd`. Loading it synchronously returns an Event containing:

- `name`: the piece's directory name;
- `duration`: a finite number of seconds, greater than zero and at most 600;
- `score`: a `Score` embedding every required SynthDef and scheduled event;
- optional `metadata`: the existing validated piece description.

The score must not boot a server, begin playback, or exit the language process.
Use timestamps in seconds, stereo output at bus 0, and internal buses starting
at 2 (the offline server has no input channels). Release sources, let their tails
finish, and explicitly free persistent effects before the end. The final second
must be silent. `scripts/render_piece.py` handles the isolated language process,
offline server, float-audio validation, PCM conversion, and optional MP3 encoding.
