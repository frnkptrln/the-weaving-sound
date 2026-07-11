(
"[temporal-binding] booting".postln;
s.waitForBoot {
    var root = thisProcess.nowExecutingPath.dirname.dirname.dirname.dirname;
    (root ++ "/core/macros.scd").load;
    (root ++ "/core/metadata.scd").load;
    (root ++ "/engines/subtractive.scd").load;
    s.sync;

    ~piece = ~weavingPiece.((
        name: "temporal-binding",
        description: "A chord-arpeggio continuum",
        engines: [\eng_subtractive_voice],
        tags: [\temporal_binding, \perception, \generative],
        mode: \finite_study,
        duration: "open",
        status: \study
    ));
    ~macros = ~weavingMacros.((
        brightness: 0.55, density: 0.45, motion: 0.0,
        space: 0.6, grit: 0.08, tension: 0.2
    ));
    ~bindingChord = [48, 55, 60, 63, 67];

    ~temporalBinding = Routine {
        var motion, onsetGap, sustain, cutoff, drive;
        loop {
            motion = ~macros[\motion];
            onsetGap = motion.linexp(0, 1, 0.012, 0.32)
                * ~macros[\density].linexp(0, 1, 1.5, 0.55);
            sustain = ~macros[\space].linlin(0, 1, 0.25, 2.8);
            cutoff = ~macros[\brightness].linexp(0, 1, 350, 7200);
            drive = ~macros[\grit].linlin(0, 1, 1.0, 3.2);

            ~bindingChord.scramble.do { |note, index|
                var voice = Synth(\eng_subtractive_voice, [
                    \freq, note.midicps,
                    \cutoff, cutoff * rrand(0.85, 1.15),
                    \res, ~macros[\tension].linlin(0, 1, 0.12, 0.55),
                    \drive, drive,
                    \rel, sustain,
                    \amp, 0.09,
                    \pan, index.linlin(0, ~bindingChord.size - 1, -0.55, 0.55)
                ]);
                SystemClock.sched(sustain, { voice.set(\gate, 0); nil });
                onsetGap.wait;
            };
            (~macros[\density].linexp(0, 1, 2.8, 0.45)).wait;
        }
    }.play(TempoClock.default);
    ~temporalBindingStop = {
        ~temporalBinding.stop;
        "[temporal-binding] stopped".postln;
    };
    "[temporal-binding] running; edit ~macros[\\motion] from 0.0 to 1.0".postln;
};
)
