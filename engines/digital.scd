// Shared digital/wavetable-like engine
(
SynthDef(\eng_digital_voice, {
    arg out=0, freq=140, amp=0.16, gate=1,
        fold=1.8, crush=10, morph=0.5, atk=0.01, dec=0.12, sus=0.7, rel=1.1, pan=0;

    var a, b, sig, env;
    a = LFTri.ar(freq * [1, 1.005]);
    b = SinOsc.ar(freq * 2.01 + (LFNoise1.ar(8) * 8));
    sig = XFade2.ar(Mix(a), b, (morph * 2) - 1);
    sig = Fold.ar(sig * fold, -0.9, 0.9);
    sig = Decimator.ar(sig, 44100 / crush.clip(1, 32), 12);
    env = EnvGen.kr(Env.adsr(atk, dec, sus, rel), gate, doneAction: 2);
    Out.ar(out, Pan2.ar(LeakDC.ar(sig) * env * amp, pan));
}).add;
)
