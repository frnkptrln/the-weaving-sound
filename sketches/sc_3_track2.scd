(
s.waitForBoot({
    fork {
        // --- 1. SETUP ---
        // Schneller, treibender Breakbeat-Vibe
        TempoClock.default.tempo = 140 / 60;
        "Lade Track 2: Kernel Panic...".postln;

        // --- 2. INSTRUMENTE ---

        // Der Reese-Bass (Tief, knurrend, extrem breit)
        SynthDef(\reese, {
            arg freq=40, amp=0.5, gate=1;
            var sig, env;
            env = EnvGen.kr(Env.asr(1.5, 1, 2), gate, doneAction: 2);
            // 4 gegeneinander verstimmte Sägezahnwellen erzeugen das "Knurren"
            sig = Mix(Saw.ar([freq, freq*1.01, freq*0.99, freq*2.005]));
            // Das Filter wandert langsam auf und ab
            sig = RLPF.ar(sig, SinOsc.kr(0.1).exprange(100, 1200), 0.3);
            Out.ar(0, Pan2.ar(sig * env * amp, 0));
        }).add;

        // Punchy Breakbeat-Kick (Kurz und hart)
        SynthDef(\punchKick, {
            arg amp=0.8;
            var sig, env, pitche;
            pitche = EnvGen.kr(Env([400, 50, 40], [0.01, 0.2], \exp));
            env = EnvGen.kr(Env.perc(0.001, 0.4), doneAction: 2);
            sig = SinOsc.ar(pitche) * env;
            // Ein minimales Rauschen für den harten Klick am Anfang
            sig = sig + (BPF.ar(WhiteNoise.ar(), 1000, 2) * env * 0.1);
            Out.ar(0, Pan2.ar(sig * amp, 0));
        }).add;

        // Glitchy Hi-Hat (FM-Synthese für metallischen Klang)
        SynthDef(\fmHat, {
            arg amp=0.3, rel=0.1;
            var sig, env;
            env = EnvGen.kr(Env.perc(0.001, rel), doneAction: 2);
            sig = SinOsc.ar(8000 * EnvGen.kr(Env([1, 0.5], [0.05]))) * env;
            sig = sig + (WhiteNoise.ar() * env * 0.5);
            sig = HPF.ar(sig, 5000); // Nur die absoluten Höhen
            Out.ar(0, Pan2.ar(sig * amp, 0));
        }).add;

        // Kristallines Pad (Kalt und maschinell)
        SynthDef(\glassPad, {
            arg freq=800, amp=0.2, gate=1;
            var sig, env;
            env = EnvGen.kr(Env.asr(2, 1, 3), gate, doneAction: 2);
            // Ringmodulation für diesen kalten, gläsernen Sound
            sig = SinOsc.ar(freq) * SinOsc.ar(freq * 1.5 + SinOsc.kr(1).range(-5, 5));
            sig = FreeVerb.ar(sig, mix: 0.7, room: 0.9, damp: 0.1);
            Out.ar(0, Pan2.ar(sig * env * amp, SinOsc.kr(0.2))); // Wandert im Stereo-Feld
        }).add;

        s.sync;
        "Instrumente geladen. System-Override initialisiert...".postln;

        // --- 3. ARRANGEMENT ---

        Routine({
            // Phase 1: Kaltes Intro (0:00 - 0:27)
            "Intro (Gefrorenes Glas)...".postln;
            ~padPlayer = Pbind(
                \instrument, \glassPad,
                \dur, 8,
                \freq, Pseq([800, 900, 750, 1000], inf),
                \amp, 0.15
            ).play(quant: 4);

            ~reesePlayer = Pbind(
                \instrument, \reese,
                \dur, 16,
                \freq, Pseq([32, 28, 30, 32].midicps, inf),
                \amp, 0.6,
                \legato, 1.0
            ).play(quant: 4);

            64.wait;

            // Phase 2: Der Breakbeat bricht ein (0:27 - 0:54)
            "Breakbeat Drop!".postln;
            ~kickPlayer = Pbind(
                \instrument, \punchKick,
                // Typischer Breakbeat-Rhythmus (nicht stur auf der 1, 2, 3, 4)
                \dur, Pseq([1.5, 0.5, 1.0, 1.0], inf),
                \amp, 0.9
            ).play(quant: 4);

            64.wait;

            // Phase 3: Glitch-Hats & Chaos (0:54 - 1:49)
            "Glitch Hats synchronisieren...".postln;
            ~hatPlayer = Pbind(
                \instrument, \fmHat,
                // Ratternde, IDM-artige Sequenz (16tel und 32stel Noten gemischt)
                \dur, Pseq([0.25, 0.25, 0.5, 0.25, 0.25, 0.125, 0.125, 0.25], inf),
                \rel, Pwhite(0.05, 0.15, inf), // Zufällige Längen
                \amp, Pwhite(0.15, 0.35, inf)  // Zufällige Betonung (Groove)
            ).play(quant: 4);

            128.wait;

            // Phase 4: System Shutdown (1:49 - Ende)
            "Shutdown Sequenz...".postln;
            ~kickPlayer.stop;
            ~hatPlayer.stop;

            // Bass wird tiefer und leiser
            ~reesePlayer.stream = Pbind(
                \instrument, \reese,
                \dur, 16,
                \freq, Pseq([28].midicps, inf),
                \amp, 0.3,
                \legato, 1.0
            ).asStream;

            32.wait;
            ~padPlayer.stop;
            ~reesePlayer.stop;

            "Track 2 beendet.".postln;

        }).play(TempoClock.default);
    }
});
)