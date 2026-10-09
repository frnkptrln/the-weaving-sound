# Lantern field

Six lights keep different hours. For a while, they learn to arrive together.
Then the agreement loosens. What stays recognizable when shared time goes away?

This is a **96-second sound sketch**, awaiting listening review. Six slow phase
oscillators trigger six pitched chime voices. Each voice keeps its register,
pitch cycle, timbre and stereo position. Their interaction changes the onsets.
The form comes from increasing and releasing their mutual coupling, rather than
editing a synchronized chord into the middle of an unrelated texture.

## Listen for

| Time | Mechanism | Listening question |
|---|---|---|
| 0–18 s | Independent clocks | Can individual strands be followed through the overlap? |
| 18–40 s | Coupling gradually rises | When do near coincidences start to sound intentional? |
| 40–60 s | Coupling holds | Do shared arrivals sound like one object or several voices? |
| 60–76 s | Coupling recedes | Is the loss of agreement gradual or suddenly noticeable? |
| 76–89 s | Independent clocks again | Does the earlier agreement change how separation is heard? |
| 89–96 s | No new onsets; decay and fade | Does the ending leave enough room for the last event? |

These are questions for listening, not established perceptual results. The
numeric phase-coherence trace describes the oscillator simulation only.

## Render

Python 3.10+ and NumPy are sufficient. No SuperCollider, samples, network calls,
model voices or audio device are used. From the repository root:

```bash
python3 -m venv /tmp/lantern-field-env
/tmp/lantern-field-env/bin/pip install -r sketches/lantern-field/requirements.txt
/tmp/lantern-field-env/bin/python sketches/lantern-field/render.py
# A listening reference with the coupling held at zero throughout:
/tmp/lantern-field-env/bin/python sketches/lantern-field/render.py --uncoupled
```

The default output is `sketches/lantern-field/renders/`: a stereo 48 kHz, 24-bit
WAV and a JSON report for each mode. `--output-dir PATH` chooses another folder;
`--sample-rate 24000` makes a smaller render. Rerunning replaces that mode's
outputs after synthesis and numerical validation succeed. The final second is
silent and the sample peak is normalized to −6 dBFS. Start playback quietly;
normalization is not a loudness judgment.

Both modes share the same initial phases, pitch cycles and synthesis rules.
Different event timing changes how many notes occur before the cutoff, and each
render is independently peak-normalized. This is an explanatory A/B reference,
not a blinded, loudness-matched perceptual experiment.

The JSON includes every onset, a per-second phase trace, score and PCM hashes,
audio levels and Python/NumPy environment information. There is no random input.
Floating-point math can vary across CPUs and NumPy versions, so the PCM hash is
diagnostic for the producing environment, not a portable golden file.

## Construction and limits

The score uses simultaneous all-to-all Kuramoto updates at 200 Hz:
`dθᵢ/dt = 2πfᵢ + K(t)/6 · Σⱼ sin(θⱼ − θᵢ)`. A full phase crossing triggers
a chime. Six fixed frequencies span 0.151–0.219 Hz; coupling reaches 0.85 rad/s.
The chimes combine decaying partials, a short attack, four quiet stereo
reflections, and a finite release. Pitch cycles deliberately have different
lengths, so shared onset timing does not freeze the harmony.

```bash
python -m unittest discover -s sketches/lantern-field -p 'test_*.py' -v
```

Tests cover score repeatability, the coupling/release arc, stereo output,
headroom, a silent tail, PCM round trips, and invalid sample rejection. CI also
renders the complete coupled score and publishes its WAV/report as an artifact.
No human listening assessment is claimed. Spectral balance, pacing, headphone
fatigue and the perceptibility of separation need that assessment before this
sketch is promoted into `pieces/` or the curated render manifest.
