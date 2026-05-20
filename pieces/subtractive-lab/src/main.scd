(
"[subtractive-lab] booting".postln;

s.waitForBoot {
    (thisProcess.nowExecutingPath.dirname.dirname.dirname.dirname ++ "/engines/subtractive.scd").load;
    s.sync;

    TempoClock.default.tempo = 124/60;

    Pdef(\subBass,
        Pbind(
            \instrument, \eng_subtractive_voice,
            \dur, Pseq([0.5,0.25,0.25,0.75,0.25], inf),
            \midinote, Pseq([36,36,39,43,34,36,41,43], inf),
            \cutoff, Pseg(Pseq([300,1400,500,2200], inf), 8, \exp),
            \res, Pwhite(0.12, 0.35),
            \waveMix, Pwhite(0.35, 0.85),
            \drive, Pwhite(1.0, 2.2),
            \amp, 0.18,
            \pan, Pwhite(-0.2,0.2)
        )
    ).play;

    "[subtractive-lab] running. stop with: Pdef(\\subBass).stop".postln;
};
)
