(
"[fm-pressure] booting".postln;

s.waitForBoot {
    thisProcess.nowExecutingPath.dirname.dirname.dirname.dirname.asString.postln;
    (thisProcess.nowExecutingPath.dirname.dirname.dirname.dirname ++ "/engines/fm.scd").load;
    s.sync;

    TempoClock.default.tempo = 122/60;

    Pdef(\fmLead,
        Pbind(
            \instrument, \eng_fm_voice,
            \scale, Scale.minor,
            \root, 0,
            \degree, Pseq([0,2,4,7,9,7,4,2], inf),
            \dur, Pseq([0.25,0.25,0.5,0.25,0.25,0.5,0.25,0.25], inf),
            \octave, Pseq([3,4,4,3], inf),
            \idx1, Pwhite(0.8, 2.8),
            \idx2, Pwhite(0.3, 1.6),
            \idx3, Pwhite(0.2, 1.0),
            \ratio2, Pwrand([1.5,2,2.5,3],[0.2,0.4,0.25,0.15],inf),
            \amp, 0.16,
            \pan, Pwhite(-0.6,0.6)
        )
    ).play;

    "[fm-pressure] running. stop with: Pdef(\\fmLead).stop".postln;
};
)
