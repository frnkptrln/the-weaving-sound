(
s.waitForBoot({
    fork {
        // --- 1. SETUP ---
        TempoClock.default.tempo = 125 / 60;
        "Lade Track 3: Daemon...".postln;

        // --- 2. INSTRUMENTE ---

        // Minimal-Kick: Sehr kurz, sehr trocken, drückt perfekt im Mix
        SynthDef(\minKick, {
            arg amp=0.9;
            var env = EnvGen.kr(Env.perc(0.001, 0.25), doneAction: 2);
            var freq = EnvGen.kr(Env([120, 50, 40], [0.01, 0.15], \exp));
            var sig = SinOsc.ar(freq) * env;
            Out.ar(0, Pan2.ar(sig * amp, 0));
        }).add;

        // Rolling Bass: Ein dumpfer Sägezahn, der perfekt in die Lücken der Kick passt
        SynthDef(\rollBass, {
            arg freq=40, amp=0.6, cutoff=200;
            var env = EnvGen.kr(Env.perc(0.05, 0.2), doneAction: 2);
            var sig = Saw.ar(freq);
            sig = RLPF.ar(sig, cutoff, 0.4);
            Out.ar(0, Pan2.ar(sig * env * amp, 0));
        }).add;

        // Der Datenstrom: Ein Arpeggio mit starkem Ping-Pong-Delay
        SynthDef(\arpPluck, {
            arg freq=440, amp=0.3, pan=0;
            var env = EnvGen.kr(Env.perc(0.01, 0.3), doneAction: 2);
            // Eine Mischung aus weichem Sinus und eckigem Puls
            var sig = Pulse.ar(freq, 0.5) + SinOsc.ar(freq);
            // Der Filter moduliert ganz langsam von selbst auf und ab
            var filterMod = SinOsc.kr(0.05).range(400, 4000);
            var delay;

            sig = LPF.ar(sig, filterMod) * env;

            // Dotted 8th Note Delay (Klassischer Techno-Echo-Effekt)
            delay = CombC.ar(sig, 1.0, 0.36, 3);
            sig = sig + (delay * 0.5);

            Out.ar(0, Pan2.ar(sig * amp, pan));
        }).add;

        // Hintergrund-Textur: Rauschen, das wie kalter Wind klingt
        SynthDef(\noiseSweep, {
            arg amp=0.15, gate=1;
            var env = EnvGen.kr(Env.asr(4, 1, 4), gate, doneAction: 2);
            var sig = WhiteNoise.ar();
            var filter = BPF.ar(sig, SinOsc.kr(0.03).exprange(200, 6000), 0.4);
            var verb = FreeVerb.ar(filter, mix: 0.8, room: 0.95);
            Out.ar(0, Pan2.ar(verb * env * amp, 0));
        }).add;

        s.sync;
        "Daemon ist im Hintergrund aktiv...".postln;

        // --- 3. ARRANGEMENT (Der Flow) ---

        Routine({
            // Phase 1: Der Datenstrom beginnt (0:00 - 0:30)
            "Verbindung hergestellt...".postln;
            ~sweep = Synth(\noiseSweep);

            ~arpPlayer = Pbind(
                \instrument, \arpPluck,
                \dur, 0.25, // Sehr schnelle 16tel-Noten
                // Die Melodie kreist ewig durch diese Noten
                \midinote, Pseq([60, 63, 67, 72, 63, 67, 60, 65, 58, 62, 65, 70], inf),
                // Panning springt zufällig von links nach rechts
                \pan, Pwhite(-0.6, 0.6, inf),
                \amp, 0.2
            ).play(quant: 4);

            64.wait;

            // Phase 2: Der Minimal-Puls (0:30 - 1:00)
            "Kick & Rolling Bass...".postln;
            ~kickPlayer = Pbind(\instrument, \minKick, \dur, 1, \amp, 0.9).play(quant: 4);

            ~bassPlayer = Pbind(
                \instrument, \rollBass,
                \dur, 0.25,
                // Das Geheimnis des Rolling Bass: Er spielt nur auf dem ZWEITEN und VIERTEN 16tel
                \amp, Pseq([0, 0.5, 0, 0.5], inf),
                \freq, Pseq([36, 36, 36, 36].midicps, inf),
                // Das Filter variiert minimal bei jedem Anschlag für einen organischen Sound
                \cutoff, Pexprand(150, 400, inf)
            ).play(quant: 4);

            64.wait;

            // Phase 3: Hypnose (Bassline mutiert) (1:00 - 1:45)
            "Polyrhythmik initialisiert...".postln;
            // Wir überschreiben die Bassline "on the fly"
            ~bassPlayer.stream = Pbind(
                \instrument, \rollBass,
                // Der Rhythmus ist jetzt eine 3er-Gruppe (0.25 + 0.25 + 0.5 = 1.0) über einem 4er-Takt!
                \dur, Pseq([0.25, 0.25, 0.5], inf),
                \amp, Pseq([0.6, 0.4, 0.6], inf),
                \freq, Pseq([36, 36, 43].midicps, inf), // Springt gelegentlich eine Quinte nach oben
                \cutoff, Pexprand(200, 700, inf)
            ).asStream;

            96.wait;

            // Phase 4: Fade Out (1:45 - Ende)
            "Verbindung wird getrennt...".postln;
            ~kickPlayer.stop;
            ~bassPlayer.stop;
            ~sweep.set(\gate, 0);

            32.wait;
            ~arpPlayer.stop;
            "Track 3 beendet.".postln;

        }).play(TempoClock.default);
    }
});
)