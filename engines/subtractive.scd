// Shared subtractive synthesis engine
(
SynthDef(\eng_subtractive_voice, {
    arg out=0, freq=110, amp=0.18, gate=1,
        waveMix=0.6, cutoff=1400, res=0.25, drive=1.2,
        atk=0.01, dec=0.15, sus=0.6, rel=1.2, pan=0;

    var saw, pulse, src, filt, env;
    saw = VarSaw.ar(freq * [1, 1.002], 0, 0.45);
    pulse = Pulse.ar(freq * 0.5, 0.42);
    src = XFade2.ar(pulse, Mix(saw), (waveMix * 2) - 1);
    src = src + WhiteNoise.ar(0.02);
    filt = RLPF.ar(src.tanh * drive, cutoff.clip(80, 14000), res.clip(0.05, 0.95));
    env = EnvGen.kr(Env.adsr(atk, dec, sus, rel), gate, doneAction: 2);
    Out.ar(out, Pan2.ar(filt * env * amp, pan));
}).add;
)
