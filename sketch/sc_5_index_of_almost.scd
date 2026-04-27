(
// =============================================================
//  INDEX OF ALMOST
//  A small generative piece about unstable choice.
//
//  It is built from things that almost become decisions:
//  hovering tones, interrupted pulses, vocal traces, and rhythmic
//  gates that keep overwriting their own certainty.
//
//  Performance controls:
//    ~ia_timeScale = 1.0;  // full duration: roughly 7 minutes
//    ~ia_density = 0.72;   // event density, useful range: 0.35..1.25
//
//  For a quick rehearsal:
//    ~ia_timeScale = 0.25;
//
//  Stop gracefully:
//    ~ia_stop.value;
// =============================================================

s.options.memSize = 65536;
s.options.numAudioBusChannels = 128;
s.options.maxNodes = 4096;
s.options.numOutputBusChannels = 2;

s.waitForBoot({
    fork {
        var toneMidi, lowMidi, vowelMidi;

        if (~ia_stop.notNil) {
            ">> [INDEX OF ALMOST] stopping previous instance...".postln;
            ~ia_stop.value;
            2.0.wait;
        };

        ~ia_timeScale = ~ia_timeScale ? 1.0;
        ~ia_density = ~ia_density ? 0.72;

        TempoClock.default.tempo = 96 / 60;

        toneMidi = [45, 48, 50, 52, 55, 57, 59, 62, 64];
        lowMidi = [28, 31, 33, 36, 38, 40];
        vowelMidi = [40, 43, 47, 50, 52];

        ">> [INDEX OF ALMOST] loading instruments...".postln;

        // ---------------------------------------------------------
        // Master: a close, reflective room with unstable memory.
        // ---------------------------------------------------------
        SynthDef(\iaMaster, {
            arg in = 0, out = 0, amp = 0.78, wet = 0.48,
                delayAmp = 0.24, room = 0.86;

            var sig, reflected, smear, verb, mixed;

            sig = LeakDC.ar(In.ar(in, 2));
            reflected = DelayC.ar(
                sig.reverse,
                1.4,
                LFNoise1.kr(0.052).range(0.07, 0.44)
            ) * delayAmp;

            smear = sig + reflected;
            smear = smear + (AllpassC.ar(smear, 0.7, [0.109, 0.157], 3.2) * 0.34);

            verb = FreeVerb2.ar(smear[0], smear[1], wet, room, 0.54);
            mixed = (smear * 0.64) + (verb * 0.58);
            mixed = HPF.ar(mixed, 28);
            mixed = LPF.ar(mixed, 9600);
            mixed = tanh(mixed * 1.17) * Lag.kr(amp, 5);
            mixed = Limiter.ar(mixed, 0.94, 0.012);

            Out.ar(out, mixed);
        }).add;

        // ---------------------------------------------------------
        // Hover: a sustained almost-chord, never fully settled.
        // ---------------------------------------------------------
        SynthDef(\iaHover, {
            arg out = 0, gate = 1, freq = 220, amp = 0.12,
                spread = 0.72, instability = 0.45, cut = 2600;

            var ratios, voices, sig, env;

            ratios = [0.5, 1.0, 1.333, 1.501, 1.997, 2.503, 3.001];
            voices = Array.fill(7, { |i|
                var drift, trem;
                drift = LFNoise2.kr(0.018 + (i * 0.009)).range(
                    1 - (0.006 * instability),
                    1 + (0.006 * instability)
                );
                trem = LFNoise2.kr(0.04 + (i * 0.031)).range(0.18, 0.92);
                SinOsc.ar(freq * ratios.wrapAt(i) * drift, 0, trem)
            });

            sig = Splay.ar(voices, spread, 1.0);
            sig = RLPF.ar(sig, cut * LFNoise2.kr(0.035).exprange(0.42, 1.38), 0.24);
            sig = sig + (BPF.ar(PinkNoise.ar(0.03 ! 2), freq * 5.1, 0.18) * instability);
            env = EnvGen.kr(Env.asr(12, 1, 18), gate, doneAction: 2);

            Out.ar(out, sig * env * amp);
        }).add;

        // ---------------------------------------------------------
        // Decision tick: a small event that tries to become a mark.
        // ---------------------------------------------------------
        SynthDef(\iaDecisionTick, {
            arg out = 0, freq = 880, amp = 0.18, pan = 0,
                decay = 0.42, doubt = 0.5;

            var click, ring, scratch, env, sig;

            click = HPF.ar(WhiteNoise.ar(0.34), 5200)
                * EnvGen.kr(Env.perc(0.0008, 0.012));
            ring = Mix(SinOsc.ar(freq * [1, 1.004, 2.017], 0, [0.32, 0.18, 0.08]));
            scratch = BPF.ar(Crackle.ar(1.35 + (doubt * 0.45)), freq * 3.7, 0.08) * 0.16;
            env = EnvGen.kr(Env.perc(0.001, decay, 1, -5), doneAction: 2);
            sig = (ring + click + scratch) * env;

            Out.ar(out, Pan2.ar(sig * amp, pan));
        }).add;

        // ---------------------------------------------------------
        // Formant shard: a breath-like syllable without words.
        // ---------------------------------------------------------
        SynthDef(\iaFormantShard, {
            arg out = 0, freq = 110, amp = 0.14, pan = 0,
                vowel = 0, hold = 1.7;

            var src, f1, f2, f3, env, sig;

            src = Saw.ar(freq * LFNoise2.kr(0.11).range(0.985, 1.015), 0.06)
                + Pulse.ar(freq * 0.5, 0.44, 0.035)
                + BrownNoise.ar(0.016);

            f1 = Select.kr(vowel.clip(0, 3), [310, 430, 620, 740]);
            f2 = Select.kr(vowel.clip(0, 3), [870, 1130, 1390, 1680]);
            f3 = Select.kr(vowel.clip(0, 3), [2050, 2380, 2650, 2920]);

            sig = BPF.ar(src, f1 * LFNoise2.kr(0.08).range(0.94, 1.08), 0.08)
                + (BPF.ar(src, f2 * LFNoise2.kr(0.06).range(0.93, 1.09), 0.06) * 0.68)
                + (BPF.ar(src, f3 * LFNoise2.kr(0.04).range(0.92, 1.1), 0.045) * 0.32);

            env = EnvGen.kr(Env([0, 1, 0.46, 0], [0.09, hold, 1.8], [-4, -1, -5]), doneAction: 2);
            sig = sig + (CombC.ar(sig, 0.8, LFNoise1.kr(0.12).range(0.09, 0.23), 2.8) * 0.22);

            Out.ar(out, Pan2.ar(sig * env * amp, pan));
        }).add;

        // ---------------------------------------------------------
        // Overwrite gate: a rhythm that erases its own outline.
        // ---------------------------------------------------------
        SynthDef(\iaOverwriteGate, {
            arg out = 0, root = 110, amp = 0.18, pan = 0,
                rate = 7, dur = 4.0, cut = 1300;

            var trig, gate, src, grit, sig, env;

            trig = Impulse.ar(rate * LFNoise1.kr(0.37).range(0.72, 1.31));
            gate = Decay2.ar(trig, 0.001, LFNoise0.kr(rate).range(0.016, 0.095));

            src = Mix(Pulse.ar(root * [1.0, 1.5, 2.01, 2.67], [0.5, 0.37, 0.22, 0.17], [0.12, 0.09, 0.06, 0.04]));
            src = RLPF.ar(src, cut * LFNoise2.kr(rate * 0.13).exprange(0.32, 3.8), 0.14);
            grit = Ringz.ar(WhiteNoise.ar(0.026) * gate, root * [4.03, 5.91], [0.16, 0.11]).sum;
            sig = (src * gate) + grit;

            env = EnvGen.kr(Env.perc(0.01, dur, 1, -3.6), doneAction: 2);
            Out.ar(out, Pan2.ar(sig * env * amp, pan));
        }).add;

        // ---------------------------------------------------------
        // Doubt dust: fast particles at the edge of attention.
        // ---------------------------------------------------------
        SynthDef(\iaDoubtDust, {
            arg out = 0, amp = 0.11, pan = 0, density = 24,
                center = 1800, dur = 1.0;

            var trig, grains, sig, env;

            trig = Dust2.ar(density);
            grains = Decay2.ar(trig, 0.001, LFNoise1.kr(8).range(0.01, 0.07));
            sig = BPF.ar(WhiteNoise.ar(0.4), center * LFNoise2.kr(11).exprange(0.48, 2.2), 0.07);
            sig = sig * grains;
            sig = sig + (Crackle.ar(1.72) * grains * 0.08);
            env = EnvGen.kr(Env.perc(0.01, dur, 1, -4), doneAction: 2);

            Out.ar(out, Pan2.ar(sig * env * amp, pan));
        }).add;

        // ---------------------------------------------------------
        // Low answer: a rare pressure response.
        // ---------------------------------------------------------
        SynthDef(\iaLowAnswer, {
            arg out = 0, freq = 48, amp = 0.32, pan = 0,
                decay = 2.8;

            var pitch, body, shade, env, sig;

            pitch = EnvGen.kr(Env([freq * 2.8, freq * 0.98, freq * 0.62], [0.045, decay], \exp));
            body = SinOsc.ar(pitch);
            shade = RLPF.ar(BrownNoise.ar(0.11), freq * LFNoise2.kr(0.3).exprange(4, 11), 0.24);
            env = EnvGen.kr(Env.perc(0.006, decay, 1, -5), doneAction: 2);
            sig = (body + shade) * env;

            Out.ar(out, Pan2.ar(sig * amp, pan));
        }).add;

        s.sync;

        ~ia_sendBus = Bus.audio(s, 2);
        ~ia_sourceGroup = Group.head(s);
        ~ia_fxGroup = Group.after(~ia_sourceGroup);
        ~ia_sustains = List.new;

        ~ia_master = Synth(\iaMaster, [
            \in, ~ia_sendBus,
            \out, 0,
            \amp, 0.76,
            \wet, 0.44,
            \delayAmp, 0.22
        ], ~ia_fxGroup);

        s.sync;

        ~ia_wait = { |seconds|
            (seconds * ~ia_timeScale * TempoClock.default.tempo).wait;
        };

        ~ia_release = { |node|
            if (node.notNil) { node.set(\gate, 0) };
        };

        ~ia_tick = { |weight = 1.0|
            Synth(\iaDecisionTick, [
                \freq, toneMidi.choose.midicps * [0.5, 1, 2].wchoose([0.16, 0.64, 0.20]),
                \amp, rrand(0.045, 0.16) * weight * ~ia_density,
                \decay, rrand(0.12, 0.9),
                \doubt, rrand(0.2, 1.0),
                \pan, rrand(-0.88, 0.88),
                \out, ~ia_sendBus
            ], ~ia_sourceGroup);
        };

        ~ia_voice = { |weight = 1.0|
            Synth(\iaFormantShard, [
                \freq, vowelMidi.choose.midicps * [0.5, 1].choose,
                \amp, rrand(0.045, 0.13) * weight * ~ia_density,
                \vowel, rrand(0, 3),
                \hold, rrand(0.45, 3.4) * ~ia_timeScale.max(0.25),
                \pan, rrand(-0.75, 0.75),
                \out, ~ia_sendBus
            ], ~ia_sourceGroup);
        };

        ~ia_dust = { |weight = 1.0|
            Synth(\iaDoubtDust, [
                \amp, rrand(0.035, 0.13) * weight * ~ia_density,
                \density, rrand(10, 58),
                \center, exprand(700, 6200),
                \dur, rrand(0.28, 2.4) * ~ia_timeScale.max(0.25),
                \pan, rrand(-1.0, 1.0),
                \out, ~ia_sendBus
            ], ~ia_sourceGroup);
        };

        ~ia_low = { |weight = 1.0|
            Synth(\iaLowAnswer, [
                \freq, lowMidi.choose.midicps,
                \amp, rrand(0.16, 0.38) * weight,
                \decay, rrand(1.8, 5.2) * ~ia_timeScale.max(0.35),
                \pan, rrand(-0.2, 0.2),
                \out, ~ia_sendBus
            ], ~ia_sourceGroup);
        };

        ~ia_gate = { |weight = 1.0|
            Synth(\iaOverwriteGate, [
                \root, toneMidi.choose.midicps * [0.5, 1].choose,
                \amp, rrand(0.055, 0.18) * weight * ~ia_density,
                \rate, [5, 7, 8, 11, 13].choose,
                \dur, rrand(1.6, 7.2) * ~ia_timeScale.max(0.25),
                \cut, exprand(480, 4200),
                \pan, rrand(-0.82, 0.82),
                \out, ~ia_sendBus
            ], ~ia_sourceGroup);
        };

        ~ia_stop = {
            var oldMaster, oldSourceGroup, oldFxGroup;

            ">> [INDEX OF ALMOST] graceful stop requested.".postln;

            oldMaster = ~ia_master;
            oldSourceGroup = ~ia_sourceGroup;
            oldFxGroup = ~ia_fxGroup;

            if (~ia_tickRtn.notNil) { ~ia_tickRtn.stop; ~ia_tickRtn = nil };
            if (~ia_dustRtn.notNil) { ~ia_dustRtn.stop; ~ia_dustRtn = nil };
            if (~ia_gateRtn.notNil) { ~ia_gateRtn.stop; ~ia_gateRtn = nil };
            if (~ia_mainRtn.notNil) { ~ia_mainRtn.stop; ~ia_mainRtn = nil };

            if (~ia_sustains.notNil) {
                ~ia_sustains.do { |node| ~ia_release.value(node) };
                ~ia_sustains.clear;
            };

            if (~ia_master.notNil) {
                ~ia_master.set(\amp, 0.0);
            };

            SystemClock.sched(14, {
                if (oldMaster.notNil) { oldMaster.free };
                if (oldSourceGroup.notNil) { oldSourceGroup.freeAll; oldSourceGroup.free };
                if (oldFxGroup.notNil) { oldFxGroup.freeAll; oldFxGroup.free };
                nil;
            });
        };

        // ---------------------------------------------------------
        // Score
        // ---------------------------------------------------------
        ~ia_mainRtn = Routine({
            var hoverA, hoverB, hoverC;

            ">> [INDEX OF ALMOST] I. empty index".postln;

            hoverA = Synth(\iaHover, [
                \freq, toneMidi.choose.midicps * 0.5,
                \amp, 0.065,
                \instability, 0.42,
                \cut, 1800,
                \out, ~ia_sendBus
            ], ~ia_sourceGroup);
            ~ia_sustains.add(hoverA);

            64.do { |i|
                if ((i % 11 == 0) and: { i > 0 }) { ~ia_tick.value(0.42) };
                if (0.055.coin) { ~ia_dust.value(0.32) };
                ~ia_wait.value(1);
            };

            ">> [INDEX OF ALMOST] II. competing hypotheses".postln;
            hoverB = Synth(\iaHover, [
                \freq, toneMidi.choose.midicps,
                \amp, 0.048,
                \spread, 0.95,
                \instability, 0.72,
                \cut, 2800,
                \out, ~ia_sendBus
            ], ~ia_sourceGroup);
            ~ia_sustains.add(hoverB);

            ~ia_tickRtn = Routine({
                loop {
                    ~ia_tick.value(0.72);
                    if (0.34.coin) { ~ia_voice.value(0.54) };
                    ~ia_wait.value(rrand(1.3, 5.8));
                };
            }).play(TempoClock.default);

            84.do { |i|
                if ((i % 17 == 0) and: { 0.7.coin }) { ~ia_low.value(0.45) };
                if (0.07.coin) { ~ia_dust.value(0.56) };
                ~ia_wait.value(1);
            };

            ">> [INDEX OF ALMOST] III. overwrite field".postln;
            hoverA.set(\amp, 0.085, \instability, 0.78, \cut, 2600);
            hoverB.set(\amp, 0.066, \instability, 0.92, \cut, 3600);
            ~ia_master.set(\wet, 0.52, \delayAmp, 0.3);

            ~ia_dustRtn = Routine({
                loop {
                    ~ia_dust.value(0.72);
                    ~ia_wait.value(rrand(0.8, 3.4));
                };
            }).play(TempoClock.default);

            ~ia_gateRtn = Routine({
                loop {
                    ~ia_gate.value(0.78);
                    if (0.22.coin) { ~ia_voice.value(0.7) };
                    ~ia_wait.value(rrand(3.0, 8.5));
                };
            }).play(TempoClock.default);

            96.do { |i|
                if ((i % 13 == 0) and: { 0.82.coin }) { ~ia_low.value(0.62) };
                if (0.05.coin) { ~ia_gate.value(0.95) };
                ~ia_wait.value(1);
            };

            ">> [INDEX OF ALMOST] IV. provisional answer".postln;
            hoverC = Synth(\iaHover, [
                \freq, toneMidi.choose.midicps * 2,
                \amp, 0.036,
                \spread, 1.0,
                \instability, 1.0,
                \cut, 5200,
                \out, ~ia_sendBus
            ], ~ia_sourceGroup);
            ~ia_sustains.add(hoverC);

            112.do { |i|
                if ((i % 8 == 0) and: { 0.62.coin }) { ~ia_gate.value(1.05) };
                if ((i % 19 == 0) and: { 0.76.coin }) { ~ia_voice.value(0.9) };
                if ((i % 31 == 0) and: { i > 0 }) {
                    3.do {
                        ~ia_tick.value(1.1);
                        ~ia_wait.value(rrand(0.09, 0.28));
                    };
                };
                ~ia_wait.value(1);
            };

            ">> [INDEX OF ALMOST] V. remainder".postln;
            if (~ia_tickRtn.notNil) { ~ia_tickRtn.stop; ~ia_tickRtn = nil };
            if (~ia_dustRtn.notNil) { ~ia_dustRtn.stop; ~ia_dustRtn = nil };
            if (~ia_gateRtn.notNil) { ~ia_gateRtn.stop; ~ia_gateRtn = nil };

            hoverA.set(\amp, 0.042, \instability, 0.34, \cut, 1400);
            hoverB.set(\amp, 0.028, \instability, 0.28, \cut, 2100);
            hoverC.set(\amp, 0.018, \instability, 0.22, \cut, 2600);
            ~ia_master.set(\wet, 0.62, \delayAmp, 0.36);

            72.do { |i|
                if ((i % 14 == 0) and: { 0.68.coin }) { ~ia_voice.value(0.36) };
                if ((i % 23 == 0) and: { 0.5.coin }) { ~ia_low.value(0.24) };
                ~ia_wait.value(1);
            };

            ~ia_sustains.do { |node| ~ia_release.value(node) };
            ~ia_sustains.clear;
            ~ia_master.set(\amp, 0.38);

            ">> [INDEX OF ALMOST] complete. Call ~ia_stop.value to clear the tail.".postln;
        }).play(TempoClock.default);

        "".postln;
        ">> [INDEX OF ALMOST] started.".postln;
        ">>    Full duration at ~ia_timeScale=1.0: roughly 7 minutes.".postln;
        ">>    Rehearsal: set ~ia_timeScale=0.25 before evaluation.".postln;
        ">>    Stop: ~ia_stop.value".postln;
        "".postln;
    };
});
)
