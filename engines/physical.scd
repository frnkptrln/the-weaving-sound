// Shared physical modelling engine
(
SynthDef(\eng_physical_pluck, {
    arg out=0, freq=220, amp=0.2, decay=3.2, coef=0.25, pan=0;
    var trig, sig, env;
    trig = Impulse.ar(0);
    sig = Pluck.ar(WhiteNoise.ar(0.45), trig, 0.2, freq.reciprocal, decay, coef);
    sig = LPF.ar(sig, freq * 5.3);
    env = EnvGen.kr(Env.perc(0.001, decay * 1.6, 1.0, -4), doneAction: 2);
    Out.ar(out, Pan2.ar(sig * env * amp, pan));
}).add;
)
