(
s.waitForBoot({
    // --- 1. TEMPO & SETUP ---
    TempoClock.default.tempo = 118 / 60;

    "Lade das Studio...".postln;

    // --- 2. DIE INSTRUMENTE (Jetzt mit Seele) ---

    // Die rohe Atmosphäre (Vinyl & Rauschen)
    SynthDef(\atmo, {
        arg amp = 0.6, fade=10;
        var env = EnvGen.kr(Env.asr(fade, 1, fade), 1); // Sehr langsames Einblenden
        var crackle = Dust2.ar(8) * 1.5;
        var hiss = LPF.ar(PinkNoise.ar(), 2000) * 0.05;
        Out.ar(0, Pan2.ar((crackle + hiss) * env * amp, 0));
    }).add;

    // Das geisterhafte Pad
    SynthDef(\ghostPad, {
        arg amp = 0.35, chordFreq=40;
        var env, sig, verb;
        // Atmet extrem langsam ein und aus (16 Takte lang)
        env = EnvGen.kr(Env.triangle(16, 1), doneAction: 2);
        // Formant-Filter lässt es wie einen Chor klingen
        sig = BPF.ar(Saw.ar([chordFreq.midicps, (chordFreq+7).midicps]), 1200 + SinOsc.kr(0.1).range(-200, 200), 0.2);
        // Ertränkt in einem endlosen Raumhall
        verb = FreeVerb2.ar(sig[0], sig[1], mix: 0.8, room: 0.95, damp: 0.1);
        Out.ar(0, verb * env * amp);
    }).add;

    // Die tiefe, weiche Kickdrum
    SynthDef(\deepKick, {
        arg amp=0.8;
        var freqEnv = EnvGen.kr(Env([80, 40, 35], [0.05, 0.4], \exp));
        var env = EnvGen.kr(Env.perc(0.01, 0.7), doneAction: 2);
        var sig = LPF.ar(SinOsc.ar(freqEnv), 250); // Extrem dumpf
        Out.ar(0, Pan2.ar(sig * env * amp, 0));
    }).add;

    // Sub-Bass (Rollt unterschwellig mit)
    SynthDef(\subBass, {
        arg freq=36, amp=0.6;
        var env = EnvGen.kr(Env.perc(0.1, 0.8), doneAction: 2);
        var sig = SinOsc.ar(freq) * env;
        Out.ar(0, Pan2.ar(sig * amp, 0));
    }).add;

    // Der Dub-Akkord (Verwaschen und moduliert)
    SynthDef(\dubChord, {
        arg freq=440, amp=0.4, cutoff=1200;
        var env = EnvGen.kr(Env.perc(0.1, 0.8), doneAction: 2);
        var sig = Mix(Pulse.ar([freq, freq*1.01, freq*0.99], 0.5));
        var filter = RLPF.ar(sig, cutoff * EnvGen.kr(Env([1, 0.2], [0.5])), 0.3);
        var delay = CombC.ar(filter, 1.0, 0.375, 4); // Tape Delay
        var verb = FreeVerb.ar(filter + (delay * 0.7), mix: 0.5, room: 0.8, damp: 0.4);
        Out.ar(0, Pan2.ar(verb * env * amp, 0));
    }).add;

    // Holziger Rimshot
    SynthDef(\rim, {
        arg amp=0.3;
        var env = EnvGen.kr(Env.perc(0.005, 0.1), doneAction: 2);
        var sig = BPF.ar(WhiteNoise.ar(), 1500, 0.4) * env;
        Out.ar(0, Pan2.ar(sig * amp, 0));
    }).add;

    s.sync;
    "Instrumente bereit. Der Track beginnt...".postln;

    // --- 3. DAS ARRANGEMENT (Der Song-Ablauf) ---
    // Eine Routine arbeitet den Track wie ein Skript ab

    Routine({
        // TAKT 1: Intro - Nur Atmo und geisterhafte Chöre
        "Intro...".postln;
        ~atmo = Synth(\atmo);

        // Der Pad-Player spielt extrem lange, atmende Akkorde
        ~padPlayer = Pbind(
            \instrument, \ghostPad,
            \dur, 16, // Alle 16 Schläge ein neuer Akkord
            \chordFreq, Pseq([48, 46, 44, 46], inf), // C-Moll Progression
            \amp, 0.4
        ).play(quant: 4);

        32.wait; // Wir warten 32 Schläge (ca. 16 Sekunden)

        // TAKT 9: Die Kick setzt ein (Herzschlag)
        "Kick kommt...".postln;
        ~kickPlayer = Pbind(
            \instrument, \deepKick,
            \dur, 1,
            \amp, 0.9
        ).play(quant: 4);

        16.wait;

        // TAKT 13: Der Sub-Bass fängt an zu rollen (Synkopiert)
        "Sub-Bass rollt...".postln;
        ~subPlayer = Pbind(
            \instrument, \subBass,
            \dur, Pseq([1.5, 1.5, 1], inf), // Treibender Rhythmus
            \freq, Pseq([36, 36, 36].midicps, inf), // Tiefes C
            \amp, 0.5
        ).play(quant: 4);

        16.wait;

        // TAKT 17: Die Dub-Akkorde brechen durch den Nebel
        "Dub Chords...".postln;
        ~chordPlayer = Pbind(
            \instrument, \dubChord,
            \dur, Pseq([3, 5], inf), // Verschlepptes Timing
            \midinote, Pseq([ [36, 43, 48, 55], [34, 41, 46, 53] ], inf),
            \cutoff, Pseq([800, 1200, 600, 2000], inf), // Filter öffnet und schließt sich
            \amp, 0.35
        ).play(quant: 4);

        16.wait;

        // TAKT 21: Der Rimshot bringt den finalen Groove
        "Groove (Rimshot)...".postln;
        ~rimPlayer = Pbind(
            \instrument, \rim,
            \dur, 1,
            \amp, Pseq([0, 0.5], inf),
            \lag, 0.03 // Leicht hinter dem Takt für den "laid-back" Vibe
        ).play(quant: 4);

        "Der Track ist jetzt voll aufgebaut. Lass ihn treiben...".postln;

    }).play(TempoClock.default); // Startet die Routine synchron zum Takt
});
)
