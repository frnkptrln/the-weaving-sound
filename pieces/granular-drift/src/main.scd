(
"[granular-drift] booting".postln;

s.waitForBoot {
    (thisProcess.nowExecutingPath.dirname.dirname.dirname.dirname ++ "/pieces/weaving-classic/src/01_synthdefs.scd").load;
    s.sync;

    ~cloud = Synth(\granular_cloud, [
        \amp, 0.16,
        \density, 14,
        \grainDur, 0.09,
        \centerFreq, 900,
        \freqSpread, 2.6
    ]);

    Routine {
        loop {
            ~cloud.set(\density, exprand(6, 28), \centerFreq, exprand(250, 3200), \grainDur, exprand(0.03, 0.18));
            rrand(2.5, 5.0).wait;
        }
    }.play(AppClock);

    "[granular-drift] running granular modulation.".postln;
};
)
