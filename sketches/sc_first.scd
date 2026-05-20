(
// --- TEMPO ---
TempoClock.default.tempo = 135 / 60; // 135 BPM

// --- INSTRUMENTE ---

// 1. Die Acid Bassline
SynthDef(\cachyAcid, {
    arg freq=440, gate=1, amp=0.2, cutoff=1000, res=0.3, pan=0;
    var sig, env, filter;
    sig = LFPulse.ar(freq, 0, 0.5);
    env = EnvGen.kr(Env.adsr(0.01, 0.3, 0.1, 0.2), gate, doneAction: 2);
    filter = RLPF.ar(sig, cutoff.lag(0.1), res);
    Out.ar(0, Pan2.ar(filter * env * amp, pan));
}).add;

// 2. Die Kick
SynthDef(\kick, {
    arg amp=0.6, out=0;
    var sig, env, pitchEnv;
    pitchEnv = EnvGen.kr(Env([150, 40, 40], [0.01, 0.2], \exp));
    env = EnvGen.kr(Env.perc(0.005, 0.3), doneAction: 2);
    sig = SinOsc.ar(pitchEnv);
    Out.ar(out, Pan2.ar(sig * env * amp, 0));
}).add;

// 3. NEU: Die Hi-Hat
SynthDef(\hat, {
    arg amp=0.3, out=0, rel=0.05; // 'rel' steuert, wie lang die Hat ist
    var sig, env;
    env = EnvGen.kr(Env.perc(0.001, rel), doneAction: 2);
    sig = WhiteNoise.ar() * env;
    sig = HPF.ar(sig, 6000); // Filtert die Bässe aus dem Rauschen
    Out.ar(out, Pan2.ar(sig * amp, 0));
}).add;

// 4. NEU: Die Snare/Clap
SynthDef(\snare, {
    arg amp=0.5, out=0;
    var sig, env;
    env = EnvGen.kr(Env.perc(0.01, 0.15), doneAction: 2);
    sig = WhiteNoise.ar() * env;
    sig = BPF.ar(sig, 2500, 1.5); // Ein Bandpass-Filter gibt den "Clap"-Charakter
    Out.ar(out, Pan2.ar(sig * amp, 0));
}).add;

"Studio ist bereit. Zeit zum Jammen!".postln;
)


// 1. Kick starten
Pdef(\kickPlayer, Pbind(\instrument, \kick, \dur, 1, \amp, 0.8)).play(quant: 4);

// 2. Bassline reindroppen lassen
(
Pdef(\acidPlayer,
    Pbind(
        \instrument, \cachyAcid,
        \dur, Pseq([0.25, 0.25, 0.5, 0.25], inf),
        \midinote, Pseq([36, 48, 36, 43, 36, 51], inf),
        \cutoff, Pseq([400, 1200, 800, 3000, 600, 2000], inf),
        \res, 0.1,
        \amp, 0.15,
        \legato, 0.9
    )
).play(quant: 4);
)

// 3. Off-Beat Hi-Hats hinzufügen (Typischer Techno-Groove)
(
Pdef(\hatPlayer,
    Pbind(
        \instrument, \hat,
        \dur, Pwhite(0.125, 0.25, inf)
        \amp, Pseq([0, 0.3], inf), // Erste Note stumm (0), zweite laut (0.3) -> Offbeat!
        \rel, 0.05
    )
).play(quant: 4);
)

// 4. Snare auf die 2 und 4 knallen lassen
(
Pdef(\snarePlayer,
    Pbind(
        \instrument, \snare,
        \dur, 0.5
        \amp, Pseq([0, 0.6], inf) // Auf jedem ZWEITEN Schlag spielen
    )
).play(quant: 4);
)


(
SynthDef(\cachyPad, {
    arg freq=440, gate=1, amp=0.3, out=0;
    var sig, env, filter;

    // Sehr langsame Hüllkurve: 2 Sekunden Attack (Einblenden), 3 Sekunden Release (Ausblenden)
    env = EnvGen.kr(Env.asr(2, 1, 3), gate, doneAction: 2);

    // 5 leicht verstimmte Sägezahn-Wellen für den "fetten" Sound
    sig = Splay.ar(Saw.ar(freq * [0.99, 1.01, 1.0, 0.995, 1.005]));

    // Ein Filter, der von alleine langsam moduliert (auf und ab wandert)
    filter = LPF.ar(sig, SinOsc.kr(0.1).range(400, 2000));

    Out.ar(out, filter * env * amp);
}).add;
)

(
Pdef(\padPlayer,
    Pbind(
        \instrument, \cachyPad,
        // Jeder Akkord wird für 8 volle Schläge gehalten
        \dur, 8,

        // Wir spielen 3-stimmige Moll-Akkorde (Bass, Terz, Quinte)
        \midinote, Pseq([
            [36, 43, 48], // C-Moll
            [34, 41, 46], // Bb-Moll
            [38, 45, 50], // D-Moll
            [36, 43, 48]  // Zurück zu C-Moll
        ], inf),

        \amp, 0.15,
        \legato, 1.0 // Die Akkorde sollen nahtlos ineinander übergehen
    )
).play(quant: 4);
)


(
// 1. SynthDef (Dein Instrument)
SynthDef(\cachyAcid, {
    arg freq=440, gate=1, amp=0.2, cutoff=1000, res=0.3, pan=0;
    var sig, env, filter;
    sig = LFPulse.ar(freq, 0, 0.5);
    env = EnvGen.kr(Env.adsr(0.01, 0.3, 0.1, 0.2), gate, doneAction: 2);
    filter = RLPF.ar(sig, cutoff.lag(0.1), res);
    Out.ar(0, Pan2.ar(filter * env * amp, pan));
}).add;

// 2. Der Player
Pdef(\acidPlayer,
    Pbind(
        \instrument, \cachyAcid,
        \dur, Pseq([0.25, 0.25, 0.5, 0.25], inf),
        \midinote, Pseq([36, 48, 36, 43, 36, 51], inf),
        // Pseq springt durch diese Filterwerte (lag im Synth sorgt für weiche Übergänge)
        \cutoff, Pseq([400, 1200, 800, 3000, 600, 2000], inf),
        \res, 0.1,
        \amp, 0.15,
        \legato, 0.9
    )
).play;
)

(
// 1. Das Instrument für die Kick-Drum
SynthDef(\kick, {
    arg amp=0.6, out=0;
    var sig, env, pitchEnv;

    // Ein extrem schneller Pitch-Drop (von 150Hz auf 40Hz) erzeugt den "Punch"
    pitchEnv = EnvGen.kr(Env([150, 40, 40], [0.01, 0.2], \exp));

    // Die Lautstärke-Hüllkurve
    env = EnvGen.kr(Env.perc(0.005, 0.3), doneAction: 2);

    // Eine simple Sinuswelle als Basis
    sig = SinOsc.ar(pitchEnv);

    Out.ar(out, Pan2.ar(sig * env * amp, 0));
}).add;

// 2. Der 4-to-the-floor Beat
Pdef(\kickPlayer,
    Pbind(
        \instrument, \kick,
        \dur, 1, // Spielt genau auf jedem ganzen Beat (Viertelnote)
        \amp, 0.8
    )
).play(quant: 1); // "quant: 1" sorgt dafür, dass Kick und Bassline im Takt synchronisieren!
)
