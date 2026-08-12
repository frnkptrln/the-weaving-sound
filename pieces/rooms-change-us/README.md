# rooms-change-us

A 92-second procedural sound room: filtered air, unstable pulses, sparse harmonic planes, short glitches, and one spoken trace:

> Manche Räume verändern nicht sich. Sie verändern uns.

The sentence is treated as an acoustic memory rather than narration. The piece grows from near-silence, briefly forms a pulse, then spends its final seconds dissolving completely.

## Structure

| Time | Event |
|---|---|
| 0:00–0:24 | room tone and low harmonic architecture |
| 0:24–0:49 | unstable pulse and fragmentary digital traces |
| ~0:49 | processed spoken sentence |
| 0:55–1:28 | residual shimmer and harmonic return |
| 1:28–1:32 | controlled fade into silence |

## Render

Requirements:

- Python 3.10+
- `espeak`
- Python packages from `requirements.txt`
- optional: `ffmpeg` for MP3 output

```bash
cd pieces/rooms-change-us
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
chmod +x start.sh
./start.sh
```

Outputs are written to `renders/` and remain untracked.

## Design notes

The renderer is deterministic (`seed=260803`) so the same composition can be reproduced and revised. It deliberately avoids a conventional song form: the pulse never settles into a beat, the voice appears only once, and the ending leaves several seconds of actual silence rather than stopping abruptly.

A browser-native sister version lives in `a-house-in-conversation/rooms/afterimage/`. It preserves the form while allowing the available system voice and audio engine to become part of the room.
