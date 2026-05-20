(
s.waitForBoot({
    fork {
        // --- 1. SETUP ---
        TempoClock.default.tempo = 118 / 60;
        "Lade das 3-Minuten-Studio...".postln;

        // --- 2. DIE INSTRUMENTE ---

        SynthDef(\atmo, {
            arg amp = 0.6, fade=10;
            var env = EnvGen.kr(Env.asr(fade, 1, fade), 1);
            var crackle = Dust2.ar(8) * 1.5;
            var hiss = LPF.ar(PinkNoise.ar(), 2000) * 0.05;
            Out.ar(0, Pan2.ar((crackle + hiss) * env * amp, 0));
        }).add;

        SynthDef(\ghostPad, {
            arg amp = 0.35, chordFreq=40;
            var env = EnvGen.kr(Env.triangle(16, 1), doneAction: 2);
            var sig = BPF.ar(Saw.ar([chordFreq.midicps, (chordFreq+7).midicps]), 1200 + SinOsc.kr(0.1).range(-200, 200), 0.2);
            var verb = FreeVerb2.ar(sig[0], sig[1], mix: 0.8, room: 0.95, damp: 0.1);
            Out.ar(0, verb * env * amp);
        }).add;

        SynthDef(\deepKick, {
            arg amp=0.8;
            var freqEnv = EnvGen.kr(Env([80, 40, 35], [0.05, 0.4], \exp));
            var env = EnvGen.kr(Env.perc(0.01, 0.7), doneAction: 2);
            var sig = LPF.ar(SinOsc.ar(freqEnv), 250);
            Out.ar(0, Pan2.ar(sig * env * amp, 0));
        }).add;

        SynthDef(\subBass, {
            arg freq=36, amp=0.6;
            var env = EnvGen.kr(Env.perc(0.1, 0.8), doneAction: 2);
            var sig = SinOsc.ar(freq) * env;
            Out.ar(0, Pan2.ar(sig * amp, 0));
        }).add;

        SynthDef(\dubChord, {
            arg freq=440, amp=0.4, cutoff=1200;
            var env = EnvGen.kr(Env.perc(0.1, 0.8), doneAction: 2);
            var sig = Mix(Pulse.ar([freq, freq*1.01, freq*0.99], 0.5));
            var filter = RLPF.ar(sig, cutoff * EnvGen.kr(Env([1, 0.2], [0.5])), 0.3);
            var delay = CombC.ar(filter, 1.0, 0.375, 4);
            var verb = FreeVerb.ar(filter + (delay * 0.7), mix: 0.5, room: 0.8, damp: 0.4);
            Out.ar(0, Pan2.ar(verb * env * amp, 0));
        }).add;

        SynthDef(\rim, {
            arg amp=0.3;
            var env = EnvGen.kr(Env.perc(0.005, 0.1), doneAction: 2);
            var sig = BPF.ar(WhiteNoise.ar(), 1500, 0.4) * env;
            Out.ar(0, Pan2.ar(sig * amp, 0));
        }).add;

        // NEU: Die melancholische Melodie (Ein weicher Pluck-Sound mit Delay)
        SynthDef(\tearPluck, {
            arg freq=440, amp=0.4;
            var env = EnvGen.kr(Env.perc(0.01, 2.5), doneAction: 2); // Langes Ausklingen
            // Eine Mischung aus weichem Sinus und leicht kratzigem Dreieck
            var sig = SinOsc.ar(freq) * 0.6 + VarSaw.ar(freq, width: 0.1) * 0.4;
            var delay;
            sig = sig * env;
            sig = LPF.ar(sig, 2000); // Sehr weich gefiltert
            // Ein Ping-Pong-ähnliches Delay für Tiefe
            delay = CombC.ar(sig, 1.0, 0.5, 5);
            Out.ar(0, Pan2.ar((sig + (delay*0.5)) * amp, 0));
        }).add;

        s.sync;
        "Instrumente bereit. Der Song beginnt...".postln;

        // --- 3. DAS ARRANGEMENT (Der unsichtbare DJ) ---
        // Bei 118 BPM ist 1 Takt (4 Beats) = ca. 2 Sekunden.
        // 64 Beats = ca. 32 Sekunden.

        Routine({
            // Phase 1: Intro (0:00 - 0:30)
            "Intro (Atmo & Choirs)...".postln;
            ~atmo = Synth(\atmo);
            ~padPlayer = Pbind(
                \instrument, \ghostPad,
                \dur, 16,
                \chordFreq, Pseq([48, 46, 44, 46], inf),
                \amp, 0.4
            ).play(quant: 4);

            64.wait;

            // Phase 2: Der Puls (0:30 - 1:00)
            "Kick & Bassline rollen rein...".postln;
            ~kickPlayer = Pbind(\instrument, \deepKick, \dur, 1, \amp, 0.9).play(quant: 4);
            ~subPlayer = Pbind(
                \instrument, \subBass,
                \dur, Pseq([1.5, 1.5, 1], inf),
                \freq, Pseq([36, 36, 36].midicps, inf),
                \amp, 0.5
            ).play(quant: 4);

            64.wait;

            // Phase 3: Groove & Dub Chords (1:00 - 1:30)
            "Dub Chords & Groove...".postln;
            ~chordPlayer = Pbind(
                \instrument, \dubChord,
                \dur, Pseq([3, 5], inf),
                \midinote, Pseq([ [36, 43, 48, 55], [34, 41, 46, 53] ], inf),
                \cutoff, Pseq([800, 1200, 600, 2000], inf),
                \amp, 0.35
            ).play(quant: 4);
            ~rimPlayer = Pbind(\instrument, \rim, \dur, 1, \amp, Pseq([0, 0.5], inf), \lag, 0.03).play(quant: 4);

            64.wait;

            // Phase 4: THE MELODY DROPS (1:30 - 2:30)
            // Die Hook! Sie kreist polyrhythmisch (Pseq mit ungeraden Werten)
            "Die Melodie setzt ein... (Augen zu!)".postln;
            ~melodyPlayer = Pbind(
                \instrument, \tearPluck,
                // Rhythmus: Spielt Noten in unregelmäßigen Abständen
                \dur, Pseq([0.5, 0.5, 1.0, 1.5, 0.5], inf),
                // Die Noten: Eine tieftraurige C-Moll Progression (C, Eb, G, Bb)
                \midinote, Pseq([60, 63, 67, 60, 70, 67, 63, 65], inf),
                \amp, Pwhite(0.15, 0.25, inf) // Leichte Variation in der Lautstärke (Humanize)
            ).play(quant: 4);

            128.wait; // Die Melodie darf über 1 Minute spielen

            // Phase 5: Der Breakdown (2:30 - 3:00)
            "Kick und Bass brechen weg... (Breakdown)".postln;
            ~kickPlayer.stop;
            ~subPlayer.stop;
            ~rimPlayer.stop;

            // Filter der Dub-Chords schließt sich langsam
            ~chordPlayer.stream = Pbind(
                \instrument, \dubChord,
                \dur, Pseq([3, 5], inf),
                \midinote, Pseq([ [36, 43, 48, 55] ], inf),
                \cutoff, 500, // Sehr dumpf!
                \amp, 0.2
            ).asStream;

            64.wait;

            // Phase 6: Outro (3:00+)
            "Fading out...".postln;
            ~melodyPlayer.stop;
            ~chordPlayer.stop;

            16.wait;
            ~padPlayer.stop;

            // Die Atmo ausklingen lassen
            ~atmo.set(\fade, 15);
            ~atmo.release;

            "Track beendet. Stille.".postln;

        }).play(TempoClock.default);
    }
});
)