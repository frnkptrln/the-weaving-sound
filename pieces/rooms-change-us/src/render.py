from __future__ import annotations

import math
import shutil
import subprocess
from pathlib import Path

import numpy as np
import soundfile as sf
from scipy import signal

SR = 44_100
DURATION = 92.0
N = int(SR * DURATION)
PIECE_DIR = Path(__file__).resolve().parent.parent
OUT = PIECE_DIR / "renders"
OUT.mkdir(parents=True, exist_ok=True)
VOICE_PATH = OUT / "voice_raw.wav"
RNG = np.random.default_rng(260803)


def smoothstep(x: np.ndarray) -> np.ndarray:
    x = np.clip(x, 0.0, 1.0)
    return x * x * (3.0 - 2.0 * x)


def window(start: float, end: float, fade_in: float, fade_out: float) -> np.ndarray:
    t = np.arange(N) / SR
    a = smoothstep((t - start) / max(fade_in, 1e-6))
    b = smoothstep((end - t) / max(fade_out, 1e-6))
    return a * b


def one_pole_lowpass(x: np.ndarray, cutoff: float) -> np.ndarray:
    b, a = signal.butter(2, cutoff / (SR / 2), btype="low")
    return signal.sosfilt(signal.tf2sos(b, a), x)


def bandpass(x: np.ndarray, low: float, high: float, order: int = 3) -> np.ndarray:
    sos = signal.butter(order, [low / (SR / 2), high / (SR / 2)], btype="band", output="sos")
    return signal.sosfilt(sos, x)


def pan_mono(x: np.ndarray, pan: float) -> np.ndarray:
    pan = float(np.clip(pan, -1.0, 1.0))
    left = math.cos((pan + 1.0) * math.pi / 4.0)
    right = math.sin((pan + 1.0) * math.pi / 4.0)
    return np.column_stack((x * left, x * right))


def add_tone(
    buf: np.ndarray,
    start: float,
    dur: float,
    freq: float,
    amp: float,
    pan: float,
    brightness: float = 0.25,
) -> None:
    i0 = int(start * SR)
    i1 = min(N, i0 + int(dur * SR))
    if i1 <= i0:
        return
    tt = np.arange(i1 - i0) / SR
    attack = np.minimum(1.0, tt / 0.06)
    release = np.exp(-tt / max(dur * 0.33, 0.1))
    env = attack * release
    drift = 0.0014 * np.sin(2 * np.pi * 0.09 * tt + RNG.uniform(0, 2 * np.pi))
    phase = 2 * np.pi * np.cumsum(freq * (1.0 + drift)) / SR
    tone = np.sin(phase)
    tone += brightness * np.sin(2.01 * phase + 0.4)
    tone += brightness * 0.28 * np.sin(3.98 * phase + 1.1)
    tone *= env * amp / (1.0 + brightness * 0.8)
    buf[i0:i1] += pan_mono(tone, pan)


def add_click(
    buf: np.ndarray,
    start: float,
    amp: float,
    pan: float,
    length: float = 0.055,
) -> None:
    i0 = int(start * SR)
    i1 = min(N, i0 + int(length * SR))
    if i1 <= i0:
        return
    tt = np.arange(i1 - i0) / SR
    noise = RNG.normal(0, 1, i1 - i0)
    noise = bandpass(noise, 900, 7600, order=2)
    env = np.exp(-tt * 70.0)
    click = amp * env * np.tanh(noise * 1.8)
    buf[i0:i1] += pan_mono(click, pan)


def sparse_reverb(stereo: np.ndarray) -> np.ndarray:
    wet = np.zeros_like(stereo)
    taps = [
        (0.113, 0.19, -0.07),
        (0.173, 0.16, 0.05),
        (0.271, 0.13, -0.04),
        (0.419, 0.10, 0.03),
        (0.673, 0.075, -0.02),
        (1.061, 0.055, 0.015),
        (1.733, 0.035, -0.01),
        (2.677, 0.022, 0.008),
    ]
    for delay, gain, cross in taps:
        d = int(delay * SR)
        if d >= N:
            continue
        wet[d:, 0] += stereo[:-d, 0] * gain + stereo[:-d, 1] * cross
        wet[d:, 1] += stereo[:-d, 1] * gain - stereo[:-d, 0] * cross
    for ch in range(2):
        wet[:, ch] = one_pole_lowpass(wet[:, ch], 6800)
    return stereo + wet


mix = np.zeros((N, 2), dtype=np.float64)
t = np.arange(N) / SR

room_noise = RNG.normal(0.0, 1.0, N)
room_noise = one_pole_lowpass(room_noise, 4200)
room_noise = bandpass(room_noise, 35, 4400, order=2)
room_env = 0.020 + 0.011 * np.sin(2 * np.pi * 0.017 * t + 0.8)
room_env *= window(0, 91.5, 3.5, 10.0)
slow_pan = np.sin(2 * np.pi * 0.008 * t)
mix[:, 0] += room_noise * room_env * (0.78 - 0.16 * slow_pan)
mix[:, 1] += room_noise * room_env * (0.78 + 0.16 * slow_pan)

hum = (
    0.014 * np.sin(2 * np.pi * 49.97 * t)
    + 0.006 * np.sin(2 * np.pi * 99.94 * t + 0.7)
    + 0.003 * np.sin(2 * np.pi * 149.91 * t + 1.4)
)
hum *= window(1.0, 88.0, 8.0, 16.0)
mix += pan_mono(hum, -0.05)

notes = [
    (4.8, 8.4, 55.0, 0.105, -0.55, 0.18),
    (9.9, 10.0, 82.41, 0.075, 0.38, 0.22),
    (15.1, 9.5, 110.0, 0.060, -0.18, 0.24),
    (20.7, 11.5, 146.83, 0.052, 0.55, 0.30),
    (27.5, 14.0, 73.42, 0.083, -0.48, 0.17),
    (35.2, 15.0, 123.47, 0.060, 0.42, 0.26),
    (43.0, 17.0, 92.50, 0.066, -0.22, 0.19),
    (55.0, 13.0, 164.81, 0.042, 0.48, 0.28),
    (62.0, 17.0, 61.74, 0.078, -0.42, 0.18),
    (71.0, 16.0, 110.0, 0.052, 0.18, 0.20),
    (78.0, 12.5, 82.41, 0.047, -0.15, 0.16),
]
for args in notes:
    add_tone(mix, *args)

pulse_times: list[float] = []
cur = 24.2
while cur < 68.0:
    pulse_times.append(cur)
    base = 0.82 if cur < 44 else 0.68
    cur += base + RNG.normal(0.0, 0.085)
for idx, pt in enumerate(pulse_times):
    strength = 0.025 + 0.023 * smoothstep(np.array([(pt - 24.0) / 18.0]))[0]
    strength *= 1.0 - 0.56 * smoothstep(np.array([(pt - 54.0) / 14.0]))[0]
    add_click(
        mix,
        pt,
        strength,
        -0.66 if idx % 2 == 0 else 0.62,
        0.045 + (idx % 3) * 0.012,
    )
    if idx % 3 != 1:
        i0 = int(pt * SR)
        length = int(0.42 * SR)
        i1 = min(N, i0 + length)
        tt = np.arange(i1 - i0) / SR
        body = np.sin(2 * np.pi * (48.0 - 12.0 * tt) * tt) * np.exp(-tt * 8.0)
        body *= strength * 1.9
        mix[i0:i1] += pan_mono(body, 0.0)

for start in [32.7, 33.1, 41.8, 42.05, 58.4, 58.72, 59.06, 66.6, 67.15, 74.3]:
    dur = RNG.uniform(0.07, 0.22)
    i0 = int(start * SR)
    i1 = min(N, i0 + int(dur * SR))
    tt = np.arange(i1 - i0) / SR
    carrier = RNG.choice([330.0, 440.0, 660.0, 880.0, 1320.0])
    sig = np.sign(np.sin(2 * np.pi * carrier * tt + RNG.uniform(0, 6.28)))
    sig *= (RNG.random(i1 - i0) > 0.17).astype(float)
    sig *= np.hanning(i1 - i0) * RNG.uniform(0.009, 0.021)
    mix[i0:i1] += pan_mono(sig, RNG.uniform(-0.85, 0.85))

if shutil.which("espeak") is None:
    raise RuntimeError("espeak is required to generate the spoken line")
subprocess.run(
    [
        "espeak",
        "-v",
        "de",
        "-s",
        "118",
        "-p",
        "31",
        "-a",
        "125",
        "-w",
        str(VOICE_PATH),
        "Manche Räume verändern nicht sich. Sie verändern uns.",
    ],
    check=True,
)
voice, voice_sr = sf.read(VOICE_PATH, dtype="float64")
if voice.ndim > 1:
    voice = voice.mean(axis=1)
if voice_sr != SR:
    target_len = int(len(voice) * SR / voice_sr)
    voice = signal.resample(voice, target_len)
voice = voice / (np.max(np.abs(voice)) + 1e-12)
voice = bandpass(voice, 115, 3900, order=3)
voice = np.tanh(voice * 1.55)
env = np.abs(signal.hilbert(voice))
env = one_pole_lowpass(env, 22)
breath = bandpass(RNG.normal(0, 1, len(voice)), 900, 6300, order=2) * env * 0.095
voice = voice * 0.205 + breath
voice_st = pan_mono(voice, -0.08)
shadow = signal.resample(voice, int(len(voice) * 1.028))
shadow = (
    shadow[: len(voice)]
    if len(shadow) >= len(voice)
    else np.pad(shadow, (0, len(voice) - len(shadow)))
)
voice_st += pan_mono(shadow * 0.075, 0.18)
voice_st = sparse_reverb(voice_st)
voice_start = 49.2
i0 = int(voice_start * SR)
i1 = min(N, i0 + len(voice_st))
voice_fade = np.ones(i1 - i0)
edge = min(int(0.25 * SR), len(voice_fade) // 2)
voice_fade[:edge] *= np.linspace(0, 1, edge)
voice_fade[-edge:] *= np.linspace(1, 0, edge)
mix[i0:i1] += voice_st[: i1 - i0] * voice_fade[:, None]

shimmer = bandpass(RNG.normal(0, 1, N), 2500, 10_500, order=2)
shimmer_mod = (0.5 + 0.5 * np.sin(2 * np.pi * (0.043 * t + 0.00022 * t * t))) ** 4
shimmer *= 0.014 * shimmer_mod * window(54.0, 86.5, 9.0, 13.5)
mix += pan_mono(shimmer, 0.2)

mix = sparse_reverb(mix)
master = window(0.0, 92.0, 3.0, 14.0)
master *= 1.0 - smoothstep((t - 89.0) / 2.2)
mix *= master[:, None]

for ch in range(2):
    mix[:, ch] = signal.sosfilt(
        signal.butter(2, 24 / (SR / 2), btype="high", output="sos"),
        mix[:, ch],
    )
mix = np.tanh(mix * 1.22)
peak = np.max(np.abs(mix))
if peak > 0:
    mix *= 0.88 / peak

sf.write(OUT / "rooms-change-us.wav", mix, SR, subtype="PCM_24")
VOICE_PATH.unlink(missing_ok=True)
print(f"Rendered {DURATION:.1f}s at {SR} Hz, peak={np.max(np.abs(mix)):.4f}")
