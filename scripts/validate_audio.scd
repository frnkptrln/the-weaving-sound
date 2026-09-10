// Invoked by validate_audio.py. Compile entrypoints without booting audio,
// then build isolated non-realtime scores from the actual shared SynthDefs.
(
{
    var root = thisProcess.argv[0], scratch = thisProcess.argv[1];
    var paths, cases, manifest, load, check, macros, gaps, rejected;
    check = { |condition, message| if(condition.not) { Error(message).throw } };
    load = { |relative| (root +/+ relative).load };
    paths = File.readAllString(scratch +/+ "sources.txt").split($\n)
        .reject(_.isEmpty);
    paths.do { |path|
        if(File.readAllString(path).compile.isNil) {
            Error("Cannot compile: " ++ path).throw;
        };
    };
    "Compiled % curated SuperCollider sources".format(paths.size).postln;

    load.("core/macros.scd");
    load.("core/metadata.scd");
    macros = ~weavingMacros.();
    check.(macros.keys.size == 6, "Macro defaults must provide six controls");
    macros = ~weavingMacros.((brightness: -2, motion: 4));
    check.(macros[\brightness] == 0 and: { macros[\motion] == 1 },
        "Macro boundary must clip values to 0..1");
    rejected = false;
    { ~weavingPiece.((name: "incomplete")) }.try { rejected = true };
    check.(rejected, "Incomplete metadata must be rejected");
    load.("pieces/temporal-binding/src/study.scd");
    gaps = [0.0, 0.25, 0.5, 0.75, 1.0].collect { |motion|
        ~bindingFrame.((motion: motion))[\onsetGap]
    };
    check.(gaps.first == 0, "Zero motion must produce simultaneous onsets");
    (gaps.size - 1).do { |index|
        check.(gaps[index + 1] > gaps[index], "Onset gaps must increase with motion")
    };
    check.(~bindingMotionAt.(0) == 0 and: {
        ~bindingMotionAt.(28) == 1 and: { ~bindingMotionAt.(55) == 0 }
    }, "Listening study must separate and return to a chord");
    check.(~bindingFrame.((space: 1))[\width] > ~bindingFrame.((space: 0))[\width],
        "Space must widen the stereo field");
    "Macro, metadata, and temporal mapping checks passed".postln;
    TempoClock.default.tempo = 1;
    #[subtractive, fm, digital, physical, software_synth].do { |name|
        load.("engines/" ++ name ++ ".scd");
    };
    load.("pieces/weaving-classic/src/01_synthdefs.scd");
    load.("pieces/weaving-classic/src/02_fx_routing.scd");

    // name, controls, gate-off time (nil for one-shots), score duration.
    // Fixed envelopes get their full natural release, including the classic pads.
    cases = [
        [\eng_subtractive_voice, [\freq, 220], 0.7, 3.0],
        [\eng_fm_voice, [\freq, 220], 0.7, 3.0],
        [\eng_digital_voice, [\freq, 220], 0.7, 3.0],
        [\eng_physical_pluck, [\freq, 220, \decay, 0.8], nil, 2.0],
        [\eng_software_poly, [\freq, 220], 0.7, 3.0],
        [\void_drone, [], 1.0, 16.0],
        [\void_pad, [], 1.0, 18.0],
        [\void_pulse, [\decay, 0.4], nil, 1.5],
        [\thread_pluck, [\decay, 0.8], nil, 2.0],
        [\chaos_glitch, [], nil, 1.5],
        [\granular_cloud, [], 1.0, 11.0],
        [\fx_master, [], nil, 16.0]
    ];
    manifest = File(scratch +/+ "cases.tsv", "w");
    protect {
        cases.do { |test|
            var name = test[0], desc = SynthDescLib.global.at(name);
            var events, gateTime = test[2], duration = test[3];
            if(desc.isNil or: { desc.def.isNil }) {
                Error("Missing compiled SynthDef: " ++ name).throw;
            };
            if(desc.outputs.size != 1 or: {
                desc.outputs[0].numberOfChannels != 2
            }) {
                Error("SynthDef must write exactly two channels: " ++ name).throw;
            };
            events = [[0.0, [\d_recv, desc.def.asBytes]]];
            if(name == \fx_master) {
                events = events ++ [
                    [0.0, [\d_recv, SynthDescLib.global.at(\void_pulse).def.asBytes]],
                    [0.05, [\s_new, \void_pulse, 1000, 0, 1,
                        \out, 2, \amp, 0.3, \decay, 0.25]],
                    [0.05, [\s_new, name, 1001, 1, 1, \in, 2, \out, 0]]
                ];
            } {
                events = events.add([0.05,
                    [\s_new, name, 1000, 0, 1, \out, 0] ++ test[1]]);
            };
            if(gateTime.notNil) {
                events = events.add([gateTime, [\n_set, 1000, \gate, 0]]);
            };
            if(name == \fx_master) {
                // Free the persistent effect after its audible tail, before
                // scsynth unloads plugins during NRT server shutdown.
                events = events.add([duration - 0.01, [\n_free, 1001]]);
            };
            events = events.add([duration, [0]]);
            Score(events).writeOSCFile(scratch +/+ (name ++ ".osc"));
            manifest.write("%\t%\t%\n".format(name, duration, gateTime ? -1));
        };
    } { manifest.close };
    "WEAVING_AUDIO_SCORES_READY".postln;
    0.exit;
}.try { |error|
    error.reportError;
    1.exit;
};
)
