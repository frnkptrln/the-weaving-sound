// Shared FM synthesis engine
(
SynthDef(\eng_fm_voice, {
    arg out=0, freq=110, amp=0.2, gate=1,
        ratio1=1.0, ratio2=2.0, ratio3=3.01,
        idx1=1.8, idx2=1.2, idx3=0.5,
        atk=0.005, dec=0.2, sus=0.55, rel=1.4, pan=0;

    var mod3, mod2, mod1, car, env;
    mod3 = SinOsc.ar(freq * ratio3, 0, freq * idx3);
    mod2 = SinOsc.ar((freq * ratio2) + mod3, 0, freq * idx2);
    mod1 = SinOsc.ar((freq * ratio1) + mod2, 0, freq * idx1);
    car  = SinOsc.ar(freq + mod1);
    env = EnvGen.kr(Env.adsr(atk, dec, sus, rel), gate, doneAction: 2);
    Out.ar(out, Pan2.ar((car * 0.8).tanh * env * amp, pan));
}).add;
)
