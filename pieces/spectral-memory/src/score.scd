// An 80-second miniature. Build a score synchronously; never boot a server here.
(
var projectDir = thisProcess.nowExecutingPath.dirname;
var root = projectDir.dirname.dirname.dirname;
var duration = 80.0, events, score, metadata;
var bellDef, floorDef, roomDef, bell, floor, phrase;
var nodeID = 1000, roomID = 900;
var previousRandomState = thisThread.randData;
var pitches = [50, 57, 64, 69, 60];
var offsets = [0.0, 0.34, 0.8, 1.24, 2.3];
var accents = [1.0, 0.62, 0.72, 0.76, 0.46];
var positions = [-0.48, 0.28, -0.12, 0.56, -0.3];

(root +/+ "core/macros.scd").load;
(root +/+ "core/metadata.scd").load;

metadata = ~weavingPiece.((
    name: "spectral-memory",
    description: "A chime becomes metal, fragments, and returns with a changed resonance",
    engines: [\spectral_memory_bell, \spectral_memory_floor],
    tags: [\spectral_identity, \inharmonicity, \memory, \chimes],
    mode: \finite_composition,
    duration: duration,
    status: \active
));

// The fundamental stays fixed while the five upper modes leave the harmonic grid.
// Every partial has its own decay; upper metal modes linger after the attack.
bellDef = SynthDef(\spectral_memory_bell, {
    arg out=2, freq=220, amp=0.1, gate=1, metal=0, decay=5.5,
        rel=2.0, cutoff=7000, pan=0, seed=1;
    var harmonic = [1, 2, 3, 4, 5, 6];
    var metallic = [1, 1.4142, 2.316, 3.571, 5.127, 7.433];
    var weights = [1, 0.45, 0.29, 0.17, 0.11, 0.07];
    var ratios, modes, strike, env, sig;
    RandSeed.ir(1, seed);
    ratios = harmonic + ((metallic - harmonic) * metal.clip(0, 1));
    modes = Mix(Array.fill(6, { |index|
        var partialEnv, detune;
        partialEnv = EnvGen.ar(Env.perc(0.002,
            decay * (1 - (index * 0.105) + (metal * index * 0.055)),
            1, -5));
        detune = SinOsc.kr(0.17 + (index * 0.073), index * 0.8,
            metal * 0.0018, 1);
        SinOsc.ar(freq * ratios[index] * detune, 0,
            weights[index] * partialEnv)
    }));
    strike = HPF.ar(WhiteNoise.ar(0.055), 1800)
        * EnvGen.ar(Env.perc(0.001, 0.024, 1, -7));
    env = EnvGen.kr(Env.asr(0.002, 1, rel), gate, doneAction: 2);
    sig = LPF.ar(modes + strike, cutoff.clip(500, 14000));
    Out.ar(out, Pan2.ar(sig * amp * env, pan));
});

// A quiet root gives the opening and return a floor; the fragmented middle loses it.
floorDef = SynthDef(\spectral_memory_floor, {
    arg out=2, freq=73.416, amp=0.035, gate=1, rel=3.8;
    var sig, env;
    sig = Mix(SinOsc.ar(freq * [1, 2.001, 3.998], [0, 0.5, 1.1],
        [1, 0.18, 0.035]));
    env = EnvGen.kr(Env.asr(1.4, 1, rel), gate, doneAction: 2);
    Out.ar(out, Pan2.ar(sig * env * amp, -0.08));
});

roomDef = SynthDef(\spectral_memory_room, {
    arg in=2, out=0, gate=1, wet=0.24;
    var dry, reflections, room, env, sig;
    dry = In.ar(in, 2);
    reflections = dry + (CombC.ar(dry, 0.8, [0.413, 0.557], 1.7) * 0.14);
    room = FreeVerb2.ar(reflections[0], reflections[1], 1, 0.84, 0.46);
    sig = (dry * (1 - wet)) + (room * wet);
    // Release the room itself after the last gesture, then free it explicitly.
    env = EnvGen.kr(Env.asr(0.03, 1, 6.8), gate);
    Out.ar(out, Limiter.ar(LeakDC.ar(sig) * 2.5 * env, 0.9, 0.01));
});

events = [
    [0.0, [\d_recv, bellDef.asBytes]],
    [0.0, [\d_recv, floorDef.asBytes]],
    [0.0, [\d_recv, roomDef.asBytes]],
    [0.01, [\s_new, \spectral_memory_room, roomID, 1, 1]]
];

bell = { |time, note, amplitude, hold, release, macros, pan, decay|
    var id = nodeID;
    nodeID = nodeID + 1;
    events = events.add([time, [\s_new, \spectral_memory_bell, id, 0, 1,
        \freq, note.midicps, \amp, amplitude,
        \metal, macros[\tension], \decay, decay, \rel, release,
        \cutoff, macros[\brightness].linexp(0, 1, 1800, 11500),
        \pan, pan.clip(-0.85, 0.85), \seed, 100000.rand + 1]]);
    events = events.add([time + hold, [\n_set, id, \gate, 0]]);
};
floor = { |time, hold, amplitude|
    var id = nodeID;
    nodeID = nodeID + 1;
    events = events.add([time, [\s_new, \spectral_memory_floor, id, 0, 1,
        \freq, 38.midicps, \amp, amplitude]]);
    events = events.add([time + hold, [\n_set, id, \gate, 0]]);
};
phrase = { |time, metal, amplitude, pace=1, brightness=0.55|
    var macros = ~weavingMacros.((
        brightness: brightness, tension: metal, space: 0.62
    ));
    pitches.do { |note, index|
        bell.(time + (offsets[index] * pace), note,
            amplitude * accents[index], 3.8, 2.0, macros,
            positions[index], 6.1)
    };
};

// Keep random choices local to this score and restore the caller's random stream.
protect {
    thisThread.randSeed = 240910;

    // I. Object, 0-18: the same asymmetrical five-note figure, with room to hear it.
    floor.(0.7, 14.8, 0.033);
    phrase.(0.9, 0.0, 0.112, 1.0, 0.5);
    phrase.(7.0, 0.025, 0.099, 1.0, 0.5);
    phrase.(13.1, 0.075, 0.088, 1.0, 0.53);

    // II. Alloy, 18-38: identical pitches and contour; their internal modes move.
    floor.(19.1, 14.0, 0.028);
    phrase.(19.0, 0.25, 0.102, 0.92, 0.61);
    phrase.(25.1, 0.53, 0.096, 0.85, 0.69);
    phrase.(31.4, 0.88, 0.087, 0.76, 0.76);
    [22.9, 29.1, 35.9].do { |time, index|
        var macros = ~weavingMacros.((brightness: 0.65, tension: 0.4 + (index * 0.25)));
        bell.(time, [76, 81, 76][index], 0.039, 2.0, 1.8,
            macros, [0.6, -0.58, 0.38][index], 4.8);
    };

    // III. Shards, 38-58: short answers, broken contour and unfilled pauses.
    events = events.add([38.0, [\n_set, roomID, \wet, 0.17]]);
    [39.2, 44.0, 49.1, 53.6].do { |time, group|
        var macros = ~weavingMacros.((brightness: 0.74, tension: 0.97));
        var notes = [[76, 69, 64], [60, 81, 76, 69],
            [57, 64, 76], [69, 60]][group];
        notes.do { |note, index|
            bell.(time + (index * 0.24) + 0.025.rand, note,
                (0.043 + 0.012.rand) * (1 - (group * 0.08)),
                0.48, 0.82, macros, rrand(-0.72, 0.72), 2.6);
        };
    };

    // IV. Trace, 58-80: root and contour return, still carrying inharmonic residue.
    events = events.add([58.0, [\n_set, roomID, \wet, 0.29]]);
    floor.(59.2, 10.5, 0.026);
    phrase.(59.8, 0.22, 0.080, 1.16, 0.48);
    phrase.(66.0, 0.14, 0.064, 1.12, 0.43);
    bell.(71.5, 50, 0.047, 2.0, 2.1,
        ~weavingMacros.((brightness: 0.36, tension: 0.12)), -0.35, 5.2);
    bell.(72.0, 76, 0.020, 1.8, 2.0,
        ~weavingMacros.((brightness: 0.5, tension: 0.43)), 0.48, 4.6);
} {
    thisThread.randData = previousRandomState;
};

events = events.add([72.05, [\n_set, roomID, \gate, 0]]);
events = events.add([79.95, [\n_free, roomID]]);
events = events.add([duration, [0]]);
score = Score(events);
(name: metadata[\name], duration: duration, score: score, metadata: metadata)
)
