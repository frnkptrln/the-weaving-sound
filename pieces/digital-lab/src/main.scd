(
"[digital-lab] booting".postln;

s.waitForBoot {
    (thisProcess.nowExecutingPath.dirname.dirname.dirname.dirname ++ "/engines/digital.scd").load;
    s.sync;

    TempoClock.default.tempo = 110/60;

    Pdef(\digitalSeq,
        Pbind(
            \instrument, \eng_digital_voice,
            \dur, Pseq([0.25,0.25,0.125,0.125,0.5], inf),
            \midinote, Pseq([48,55,60,63,67,70,72,74], inf),
            \morph, Pwhite(0.0, 1.0),
            \fold, Pwhite(1.2, 2.8),
            \crush, Pwhite(4, 20),
            \amp, 0.15,
            \pan, Pwhite(-0.4, 0.4)
        )
    ).play;

    "[digital-lab] running. stop with: Pdef(\\digitalSeq).stop".postln;
};
)
