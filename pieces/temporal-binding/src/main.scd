(
// Capture the path while this file is executing, before the boot callback.
var projectDir = thisProcess.nowExecutingPath.dirname;
var root = projectDir.dirname.dirname.dirname;
"[temporal-binding] booting".postln;
s.waitForBoot {
    var activeVoices = IdentitySet.new;
    var routine, playNote;
    if(~temporalBindingStop.notNil) { ~temporalBindingStop.() };
    (root +/+ "core/macros.scd").load;
    (root +/+ "core/metadata.scd").load;
    (root +/+ "engines/subtractive.scd").load;
    (projectDir +/+ "study.scd").load;
    s.sync;

    ~piece = ~weavingPiece.((
        name: "temporal-binding",
        description: "A chord-arpeggio continuum",
        engines: [\eng_subtractive_voice],
        tags: [\temporal_binding, \perception, \generative],
        mode: \interactive_study,
        duration: "open",
        status: \study
    ));
    ~macros = ~weavingMacros.((
        brightness: 0.55, density: 0.45, motion: 0.0,
        space: 0.6, grit: 0.08, tension: 0.2
    ));
    // Called inside s.bind so starts and releases share server latency.
    playNote = { |note, index, frame|
        var voice = Synth(\eng_subtractive_voice,
            ~bindingVoiceArgs.(note, index, frame));
        activeVoices.add(voice);
        SystemClock.sched(frame[\hold], {
            s.bind {
                if(activeVoices.includes(voice)) {
                    voice.set(\gate, 0);
                    activeVoices.remove(voice);
                };
            };
            nil
        });
    };
    routine = Routine {
        loop {
            var frame = ~bindingFrame.(~macros);
            if(frame[\onsetGap] == 0) {
                // One bundle guarantees simultaneous starts on the server.
                s.bind {
                    ~bindingChord.do { |note, index| playNote.(note, index, frame) };
                };
            } {
                ~bindingChord.do { |note, index|
                    s.bind { playNote.(note, index, frame) };
                    frame[\onsetGap].wait;
                };
            };
            frame[\rest].wait;
        }
    };
    ~temporalBinding = routine;
    ~temporalBindingStop = {
        routine.stop;
        s.bind { activeVoices.do { |voice| voice.set(\gate, 0) } };
        activeVoices.clear;
        "[temporal-binding] stopped; remaining voices release".postln;
    };
    routine.play(SystemClock);
    "[temporal-binding] running; edit ~macros[\\motion] from 0.0 to 1.0".postln;
};
)
