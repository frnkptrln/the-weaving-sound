# A place left for you

A 132-second sketch for three synthetic voices and the echoes they share.
One five-note contour first belongs to a low, soft pluck. A reed-like voice
and a small glass tone take it up. Later, the notes of a phrase pass between
all three. The last answers shorten. After the sources stop, only returns
from earlier phrases remain.

**Listening question:** when a phrase loses its original voice, can the
shared returns still make its absence audible?

This is an unreviewed sketch, not a new member of the curated listening
edition. Its title describes an artistic intention; the mechanism makes no
claim about social memory, cognition or a physical room.

| Time | Form |
| --- | --- |
| 0–34 s | One low voice introduces the contour. |
| 34–69.5 s | Other voices inherit it, changing octave and color. |
| 69.5–92 s | Successive notes pass between all three voices. |
| 92–112 s | Shorter answers; the last source begins at 105.5 s. |
| 112–131 s | Only the shared echoes; a final eight-second fade. |
| 131–132 s | Digital silence. |

## Render

From the repository root, with Python 3.10+:

```bash
python -m pip install -r sketches/a-place-left-for-you/requirements.txt
python sketches/a-place-left-for-you/render.py
python sketches/a-place-left-for-you/render.py --memory-off
python -m unittest discover -s sketches/a-place-left-for-you -p 'test_*.py' -v
```

The default output is a 48 kHz, stereo, 24-bit WAV and a JSON report in
`renders/` beside this README. `--output-dir PATH` changes that destination;
`--sample-rate 24000` gives a smaller rehearsal render. No audio device,
samples, model service or SuperCollider installation is needed.

The score is authored and deterministic. Harmonic pluck, soft reed and
slightly stretched bell spectra distinguish the voices. Short reflections
remain in both versions. Two shared delay lines, 7.5 and 11.25 seconds long,
each return the original dry signal six times at decreasing gain, alternating
stereo direction. This is an explicitly truncated echo construction, not a
simulation of an acoustic room or an unbounded feedback network.

`--memory-off` uses the **same score and the full version's normalization
gain**, removing only the long returns. Before the first long return, both
versions are sample-identical within the same environment. It is a mechanism
reference, not a perceptually loudness-matched or blinded listening study.

The full version peaks at −6 dBFS. Both end with one silent second. Reports
record the score and PCM hashes, runtime versions and per-second RMS.
Repeatability is tested on the same environment; hashes are diagnostic across
different CPU/NumPy versions. The CI workflow renders both versions and makes
their WAVs and reports available as temporary artifacts.

## Before becoming a piece

Listen through both versions on headphones and speakers. Does the middle
actually feel like a handoff? Are the echoes too literal or too crowded?
Does the extended departure earn its length? Numeric checks cannot answer
these questions. The existing pieces and their manifest are unchanged.
