(
"[software-synth-lab] booting".postln;

s.waitForBoot {
    (thisProcess.nowExecutingPath.dirname.dirname.dirname.dirname ++ "/engines/software_synth.scd").load;
    s.sync;

    TempoClock.default.tempo = 128/60;

    Pdef(\softChords,
        Pbind(
            \instrument, \eng_software_poly,
            \dur, 0.5,
            \freq, Pseq([
                [55, 82.41, 110],
                [61.74, 92.5, 123.47],
                [65.41, 98, 130.81],
                [49, 73.42, 98]
            ].collect(_.choose), inf),
            \detune, Pwhite(0.006, 0.02),
            \cutoff, Pwhite(700, 3800),
            \amp, 0.14
        )
    ).play;

    "[software-synth-lab] running. stop with: Pdef(\\softChords).stop".postln;
};
)
