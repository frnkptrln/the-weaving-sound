// Finite listening study, using the same voice and mapping as main.scd.
// scsynth runs in non-realtime mode: no server boot or audio device is needed.
(
var projectDir = thisProcess.nowExecutingPath.dirname;
var root = projectDir.dirname.dirname.dirname;
var outputDir = projectDir.dirname +/+ "renders";
var score, frame, values, time = 0.1, nodeID = 1000;
var duration = 64.0;
var options = ServerOptions.new.numOutputBusChannels_(2).numInputBusChannels_(0).verbosity_(-1);

try {
    (root +/+ "core/macros.scd").load;
    (root +/+ "engines/subtractive.scd").load;
    (projectDir +/+ "study.scd").load;
    File.mkdir(outputDir);
    // Score timestamps are seconds at this explicit tempo.
    TempoClock.default.tempo = 1;
    score = Score([
        [0.0, [\d_recv, SynthDescLib.global.at(\eng_subtractive_voice).def.asBytes]]
    ]);
    values = ~weavingMacros.((
        brightness: 0.55, density: 0.45, space: 0.6, grit: 0.08, tension: 0.2
    ));
    while { time < 56.0 } {
        values[\motion] = ~bindingMotionAt.(time - 0.1);
        frame = ~bindingFrame.(values);
        ~bindingChord.do { |note, index|
            score.add([time, [\s_new, \eng_subtractive_voice, nodeID, 0, 1]
                ++ ~bindingVoiceArgs.(note, index, frame)]);
            score.add([time + frame[\hold], [\n_set, nodeID, \gate, 0]]);
            nodeID = nodeID + 1;
            time = time + frame[\onsetGap];
        };
        time = time + frame[\rest];
    };
    score.recordNRT(
        oscFilePath: outputDir +/+ "temporal-binding.osc",
        outputFilePath: outputDir +/+ "temporal-binding.wav",
        sampleRate: 48000,
        headerFormat: "WAV",
        sampleFormat: "int24",
        options: options,
        duration: duration,
        action: { |exitCode|
            if(exitCode == 0) { "[temporal-binding] rendered 64-second study".postln };
            exitCode.exit;
        }
    );
} { |error|
    error.reportError;
    1.exit;
};
)
