(
"[physical-lab] booting".postln;

s.waitForBoot {
    (thisProcess.nowExecutingPath.dirname.dirname.dirname.dirname ++ "/engines/physical.scd").load;
    s.sync;

    TempoClock.default.tempo = 90/60;

    Pdef(\physPlucks,
        Pbind(
            \instrument, \eng_physical_pluck,
            \scale, Scale.dorian,
            \root, -2,
            \degree, Prand([0,2,3,5,7,9], inf),
            \octave, Prand([3,4,5], inf),
            \dur, Pwrand([0.25,0.5,0.75,1.0],[0.25,0.35,0.25,0.15], inf),
            \decay, Pwhite(1.8, 5.0),
            \coef, Pwhite(0.12, 0.45),
            \amp, 0.18,
            \pan, Pwhite(-0.8, 0.8)
        )
    ).play;

    "[physical-lab] running. stop with: Pdef(\\physPlucks).stop".postln;
};
)
