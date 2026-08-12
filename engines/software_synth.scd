// Shared software-synth hybrid supersaw engine
(
SynthDef(\eng_software_poly, {
    arg out=0, freq=110, amp=0.18, gate=1, detune=0.012, cutoff=2200, rq=0.22, pan=0;
    var freqs, sig, env;
    freqs = [freq*(1-detune), freq, freq*(1+detune), freq*2];
    sig = Mix(VarSaw.ar(freqs, 0, 0.55, [0.3,0.35,0.3,0.15]));
    sig = MoogFF.ar(sig, cutoff.clip(120, 14000), 2.1);
    sig = Splay.ar([sig, DelayC.ar(sig,0.03,0.011)], spread: 0.35);
    env = EnvGen.kr(Env.adsr(0.02,0.15,0.68,1.5), gate, doneAction: 2);
    // Splay is already stereo. Balance2 preserves two-channel output.
    sig = Balance2.ar(sig[0], sig[1], pan);
    Out.ar(out, sig * env * amp);
}).add;
)
