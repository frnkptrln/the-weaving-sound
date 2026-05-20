(
// =============================================================
//  BETONMEMBRAN
//  An industrial hall study for large-scale sound systems.
//
//  Idea:
//  The building is treated as a pressure instrument: sub-bass
//  air, steel resonances, electrical arc dust, and a late grid
//  that feels more like infrastructure than club rhythm.
//
//  Performance controls:
//    ~kw_timeScale = 1.0;  // full duration: roughly 12-14 minutes
//    ~kw_intensity = 0.78; // master material density, 0.3..1.2
//
//  For rehearsals, evaluate this before running:
//    ~kw_timeScale = 0.18;
//
//  Stop gracefully:
//    ~kw_stop.value;
// =============================================================

// Server options must be set before boot. If the server is already
// running, these lines are harmless but may not take effect until reboot.
s.options.memSize = 131072;
s.options.numAudioBusChannels = 128;
s.options.maxNodes = 8192;
s.options.numOutputBusChannels = 2;

s.waitForBoot({
    fork {
        var rootMidi, lowMidi, formantRoots;

        if (~kw_stop.notNil) {
            ">> [BETONMEMBRAN] stopping previous instance...".postln;
            ~kw_stop.value;
            2.0.wait;
        };

        ~kw_timeScale = ~kw_timeScale ? 1.0;
        ~kw_intensity = ~kw_intensity ? 0.78;

        TempoClock.default.tempo = 118 / 60;

        rootMidi = [26, 31, 33, 38, 40];       // D, G, A, D, E pressure roots
        lowMidi = [21, 24, 26, 28, 31, 33];    // sub floor
        formantRoots = [43, 45, 48, 50, 52];   // low choir register

        ">> [BETONMEMBRAN] loading hall instruments...".postln;

        // ---------------------------------------------------------
        // Master: tape-smear, hall wash, saturation, limiter.
        // ---------------------------------------------------------
        SynthDef(\kwMaster, {
            arg in = 0, out = 0, amp = 0.82, delayAmp = 0.34,
                revMix = 0.46, room = 0.94;

            var sig, dry, wobble, echo, smeared, verb;

            sig = LeakDC.ar(In.ar(in, 2));
            dry = sig;

            wobble = LFNoise1.kr(0.07).range(-0.018, 0.018);
            echo = CombC.ar(
                sig,
                2.4,
                [0.376, 0.563] + wobble,
                5.5
            ) * delayAmp;
            echo = LPF.ar(echo, 2600);

            smeared = dry + echo;
            smeared = smeared + (AllpassC.ar(smeared, 0.6, [0.071, 0.089], 3.8) * 0.42);

            verb = FreeVerb2.ar(
                smeared[0],
                smeared[1],
                revMix,
                room,
                0.63
            );

            sig = (smeared * 0.58) + (verb * 0.62);
            sig = HPF.ar(sig, 24);
            sig = LPF.ar(sig, 11800);
            sig = tanh(sig * 1.22) * Lag.kr(amp, 6);
            sig = Limiter.ar(sig, 0.95, 0.012);

            Out.ar(out, sig);
        }).add;

        // ---------------------------------------------------------
        // Concrete breath: long sub pressure and shifting formants.
        // ---------------------------------------------------------
        SynthDef(\kwConcreteBreath, {
            arg out = 0, gate = 1, freq = 36, amp = 0.22,
                pressure = 0.55, tilt = 140;

            var breath, sub, rub, body, formants, env, pan;

            breath = SinOsc.kr(0.021).range(0.48, 1.0)
                + LFNoise2.kr(0.055).range(-0.12, 0.12);

            sub = Mix(SinOsc.ar(freq * [0.5, 1.0, 1.006], 0, [0.34, 0.48, 0.34]));
            rub = Mix(LFSaw.ar(freq * [1.997, 2.013], 0, 0.035));
            body = (sub + rub) * pressure;

            formants = Mix([
                Resonz.ar(body, tilt * LFNoise2.kr(0.032).exprange(0.55, 1.7), 0.052),
                Resonz.ar(body, tilt * 2.9 * LFNoise2.kr(0.027).exprange(0.72, 1.42), 0.038),
                RLPF.ar(body, tilt * 5.1 * LFNoise2.kr(0.041).exprange(0.38, 1.2), 0.18)
            ]);

            env = EnvGen.kr(Env.asr(18, 1, 26), gate, doneAction: 2);
            pan = SinOsc.kr(0.011).range(-0.22, 0.22);

            Out.ar(out, Pan2.ar((body * 0.38 + formants * 0.85) * breath * env * amp, pan));
        }).add;

        // ---------------------------------------------------------
        // Steel beam: struck structural resonance.
        // ---------------------------------------------------------
        SynthDef(\kwSteelBeam, {
            arg out = 0, freq = 72, amp = 0.34, decay = 7.0,
                pan = 0, bright = 1.0;

            var hitEnv, exc, freqs, amps, rings, sig, env;

            hitEnv = EnvGen.kr(Env.perc(0.001, 0.045));
            exc = (PinkNoise.ar(0.55) + WhiteNoise.ar(0.22)) * hitEnv;

            freqs = freq * [1.0, 1.497, 2.031, 2.873, 3.967, 5.41, 7.32];
            amps = [1.0, 0.72, 0.46, 0.34, 0.23, 0.17, 0.10];
            rings = decay * [1.0, 0.78, 0.62, 0.48, 0.36, 0.24, 0.16];

            sig = Mix(Ringz.ar(exc, freqs, rings, amps)) * 0.075;
            sig = HPF.ar(sig, 55);
            sig = LPF.ar(sig, bright.linexp(0.2, 1.6, 1700, 9300));

            env = EnvGen.kr(Env.linen(0.001, decay, 0.2), doneAction: 2);
            Out.ar(out, Pan2.ar(sig * env * amp, pan));
        }).add;

        // ---------------------------------------------------------
        // Arc flash: short, dangerous electrical dust.
        // ---------------------------------------------------------
        SynthDef(\kwArcFlash, {
            arg out = 0, amp = 0.22, pan = 0, density = 34,
                tone = 2600, dur = 0.35;

            var burst, electric, hiss, sig, env;

            burst = Decay2.ar(Dust2.ar(density), 0.001, LFNoise1.kr(9).range(0.012, 0.085));
            electric = Crackle.ar(LFNoise1.kr(28).range(1.18, 1.97)) * burst;
            electric = BPF.ar(electric, tone * LFNoise2.kr(13).exprange(0.42, 2.6), 0.075);

            hiss = HPF.ar(WhiteNoise.ar(0.28), 4600) * burst;
            sig = electric + (hiss * 0.33);

            env = EnvGen.kr(Env.perc(0.001, dur), doneAction: 2);
            Out.ar(out, Pan2.ar(sig * env * amp, pan));
        }).add;

        // ---------------------------------------------------------
        // Pressure pulse: sub hit without normal kick-drum comfort.
        // ---------------------------------------------------------
        SynthDef(\kwPressurePulse, {
            arg out = 0, freq = 41, amp = 0.62, decay = 1.05, pan = 0;

            var pitch, body, air, env, sig;

            pitch = EnvGen.kr(Env([freq * 4.6, freq * 1.08, freq * 0.74], [0.024, decay], \exp));
            body = SinOsc.ar(pitch);
            air = RLPF.ar(PinkNoise.ar(0.22), freq * 7.0, 0.22);

            env = EnvGen.kr(Env.perc(0.002, decay, 1, -5.2), doneAction: 2);
            sig = (body + (air * 0.46)) * env;

            Out.ar(out, Pan2.ar(sig * amp, pan));
        }).add;

        // ---------------------------------------------------------
        // Crowd formant: not a sample, more like the building
        // remembering human vowels through ventilation shafts.
        // ---------------------------------------------------------
        SynthDef(\kwCrowdFormant, {
            arg out = 0, gate = 1, freq = 110, amp = 0.11,
                vowel = 0, pan = 0;

            var src, f1, f2, f3, sig, env;

            src = Mix([
                Saw.ar(freq * LFNoise2.kr(0.05).range(0.992, 1.008), 0.06),
                Pulse.ar(freq * 0.5, 0.43, 0.035),
                BrownNoise.ar(0.018)
            ]);

            f1 = Select.kr(vowel.clip(0, 3), [320, 520, 690, 410]);
            f2 = Select.kr(vowel.clip(0, 3), [930, 1180, 1550, 840]);
            f3 = Select.kr(vowel.clip(0, 3), [2480, 2100, 2700, 1890]);

            sig = BPF.ar(src, f1 * LFNoise2.kr(0.03).range(0.94, 1.08), 0.075)
                + (BPF.ar(src, f2 * LFNoise2.kr(0.026).range(0.92, 1.1), 0.055) * 0.72)
                + (BPF.ar(src, f3 * LFNoise2.kr(0.021).range(0.9, 1.12), 0.04) * 0.38);

            sig = sig + (CombC.ar(sig, 0.9, LFNoise1.kr(0.04).range(0.13, 0.31), 4.2) * 0.23);
            env = EnvGen.kr(Env.asr(9, 1, 13), gate, doneAction: 2);

            Out.ar(out, Pan2.ar(sig * env * amp, pan));
        }).add;

        // ---------------------------------------------------------
        // Magnetic gate: late-stage infrastructure rhythm.
        // ---------------------------------------------------------
        SynthDef(\kwMagneticGate, {
            arg out = 0, root = 45, amp = 0.24, rate = 8,
                cut = 900, pan = 0, dur = 6.0;

            var trig, gate, src, mono, stereo, env;

            trig = Impulse.ar(rate * LFNoise1.kr(0.35).range(0.78, 1.24));
            gate = Decay2.ar(trig, 0.002, LFNoise0.kr(rate).range(0.025, 0.13));

            src = Mix(Pulse.ar(root * [1.0, 1.5, 2.01], [0.42, 0.35, 0.19], [0.18, 0.12, 0.08]));
            mono = RLPF.ar(src, cut * LFNoise1.kr(rate * 0.22).exprange(0.45, 4.2), 0.16) * gate;
            stereo = Pan2.ar(mono, pan) + (CombC.ar(mono, 0.6, [0.126, 0.189], 1.55) * 0.42);

            env = EnvGen.kr(Env.perc(0.015, dur), doneAction: 2);
            Out.ar(out, stereo * env * amp);
        }).add;

        s.sync;

        ~kw_sendBus = Bus.audio(s, 2);
        ~kw_sourceGroup = Group.head(s);
        ~kw_fxGroup = Group.after(~kw_sourceGroup);
        ~kw_sustains = List.new;

        ~kw_master = Synth(\kwMaster, [
            \in, ~kw_sendBus,
            \out, 0,
            \amp, 0.78,
            \delayAmp, 0.33,
            \revMix, 0.48
        ], ~kw_fxGroup);

        s.sync;

        ~kw_wait = { |beats|
            (beats * ~kw_timeScale).wait;
        };

        ~kw_release = { |node|
            if (node.notNil) { node.set(\gate, 0) };
        };

        ~kw_spawnBeam = { |weight = 1.0|
            Synth(\kwSteelBeam, [
                \freq, (rootMidi.choose.midicps * [0.5, 1, 2].wchoose([0.2, 0.62, 0.18])),
                \amp, rrand(0.13, 0.36) * weight * ~kw_intensity,
                \decay, rrand(3.8, 13.0),
                \bright, rrand(0.45, 1.45),
                \pan, rrand(-0.9, 0.9),
                \out, ~kw_sendBus
            ], ~kw_sourceGroup);
        };

        ~kw_spawnArc = { |weight = 1.0|
            Synth(\kwArcFlash, [
                \amp, rrand(0.07, 0.24) * weight * ~kw_intensity,
                \density, rrand(16, 72),
                \tone, exprand(900, 7600),
                \dur, rrand(0.06, 0.74),
                \pan, rrand(-1.0, 1.0),
                \out, ~kw_sendBus
            ], ~kw_sourceGroup);
        };

        ~kw_spawnPulse = { |weight = 1.0|
            Synth(\kwPressurePulse, [
                \freq, lowMidi.choose.midicps,
                \amp, rrand(0.26, 0.72) * weight * ~kw_intensity,
                \decay, rrand(0.72, 1.85),
                \pan, rrand(-0.18, 0.18),
                \out, ~kw_sendBus
            ], ~kw_sourceGroup);
        };

        ~kw_startArcField = { |weight = 1.0, gapLo = 0.55, gapHi = 4.5|
            if (~kw_arcRtn.notNil) { ~kw_arcRtn.stop };
            ~kw_arcRtn = Routine({
                loop {
                    if (0.84.coin) { ~kw_spawnArc.value(weight) };
                    ~kw_wait.value(rrand(gapLo, gapHi));
                };
            }).play(TempoClock.default);
        };

        ~kw_startBeamField = { |weight = 1.0, gapLo = 4.0, gapHi = 17.0|
            if (~kw_beamRtn.notNil) { ~kw_beamRtn.stop };
            ~kw_beamRtn = Routine({
                loop {
                    ~kw_spawnBeam.value(weight);
                    if (0.28.coin) {
                        ~kw_wait.value(rrand(0.18, 0.74));
                        ~kw_spawnBeam.value(weight * 0.65);
                    };
                    ~kw_wait.value(rrand(gapLo, gapHi));
                };
            }).play(TempoClock.default);
        };

        ~kw_startPulseGrid = { |weight = 1.0|
            if (~kw_pulseRtn.notNil) { ~kw_pulseRtn.stop };
            ~kw_pulseRtn = Routine({
                var pattern;
                pattern = [1, 0.5, 0.5, 1.5, 0.5, 1, 2, 0.5, 0.5, 3];
                loop {
                    pattern.do { |dur, i|
                        if ((i == 0) or: { 0.42.coin }) { ~kw_spawnPulse.value(weight) };
                        if (0.2.coin) {
                            Synth(\kwMagneticGate, [
                                \root, rootMidi.choose.midicps,
                                \rate, [6, 7, 8, 11, 13].choose,
                                \dur, rrand(2.0, 7.5) * ~kw_timeScale.max(0.2),
                                \cut, exprand(360, 2800),
                                \amp, rrand(0.08, 0.22) * weight * ~kw_intensity,
                                \pan, rrand(-0.75, 0.75),
                                \out, ~kw_sendBus
                            ], ~kw_sourceGroup);
                        };
                        ~kw_wait.value(dur);
                    };
                };
            }).play(TempoClock.default);
        };

        ~kw_stop = {
            var oldMaster, oldSourceGroup, oldFxGroup;

            ">> [BETONMEMBRAN] graceful stop requested.".postln;

            oldMaster = ~kw_master;
            oldSourceGroup = ~kw_sourceGroup;
            oldFxGroup = ~kw_fxGroup;

            if (~kw_arcRtn.notNil) { ~kw_arcRtn.stop; ~kw_arcRtn = nil };
            if (~kw_beamRtn.notNil) { ~kw_beamRtn.stop; ~kw_beamRtn = nil };
            if (~kw_pulseRtn.notNil) { ~kw_pulseRtn.stop; ~kw_pulseRtn = nil };
            if (~kw_mainRtn.notNil) { ~kw_mainRtn.stop; ~kw_mainRtn = nil };

            if (~kw_sustains.notNil) {
                ~kw_sustains.do { |node| ~kw_release.value(node) };
                ~kw_sustains.clear;
            };

            if (~kw_master.notNil) {
                ~kw_master.set(\amp, 0.0);
            };

            SystemClock.sched(18, {
                if (oldMaster.notNil) { oldMaster.free };
                if (oldSourceGroup.notNil) { oldSourceGroup.freeAll; oldSourceGroup.free };
                if (oldFxGroup.notNil) { oldFxGroup.freeAll; oldFxGroup.free };
                nil;
            });
        };

        // ---------------------------------------------------------
        // The performance score.
        // ---------------------------------------------------------
        ~kw_mainRtn = Routine({
            var drone, choir;

            ">> [BETONMEMBRAN] I. air pressure / empty turbine hall".postln;

            drone = Synth(\kwConcreteBreath, [
                \freq, lowMidi.choose.midicps,
                \amp, 0.15 * ~kw_intensity,
                \pressure, 0.46,
                \tilt, rrand(90, 170),
                \out, ~kw_sendBus
            ], ~kw_sourceGroup);
            ~kw_sustains.add(drone);

            ~kw_startArcField.value(0.42, 2.8, 9.0);

            96.do { |i|
                if ((i % 23 == 0) and: { i > 0 }) { ~kw_spawnBeam.value(0.35) };
                ~kw_wait.value(1);
            };

            ">> [BETONMEMBRAN] II. steel remembers the grid".postln;
            drone.set(\amp, 0.22 * ~kw_intensity, \pressure, 0.62, \tilt, rrand(130, 240));
            ~kw_startBeamField.value(0.72, 5.0, 14.0);
            ~kw_startArcField.value(0.72, 1.1, 5.8);

            160.do { |i|
                if ((i % 37 == 0) and: { 0.68.coin }) { ~kw_spawnPulse.value(0.42) };
                if (0.035.coin) { ~kw_spawnArc.value(1.1) };
                ~kw_wait.value(1);
            };

            ">> [BETONMEMBRAN] III. crowd afterimage / ventilation choir".postln;
            choir = Array.fill(5, { |i|
                var node;
                node = Synth(\kwCrowdFormant, [
                    \freq, formantRoots.wrapAt(i).midicps * [0.5, 1].choose,
                    \amp, rrand(0.045, 0.095) * ~kw_intensity,
                    \vowel, i % 4,
                    \pan, i.linlin(0, 4, -0.72, 0.72),
                    \out, ~kw_sendBus
                ], ~kw_sourceGroup);
                ~kw_sustains.add(node);
                node;
            });

            ~kw_master.set(\delayAmp, 0.41, \revMix, 0.57);
            192.do { |i|
                if ((i % 16 == 0) and: { 0.72.coin }) { ~kw_spawnBeam.value(0.52) };
                if (0.08.coin) { ~kw_spawnArc.value(0.68) };
                if (0.018.coin) { ~kw_spawnPulse.value(0.5) };
                ~kw_wait.value(1);
            };

            ">> [BETONMEMBRAN] IV. atonal grid / infrastructure turns rhythmic".postln;
            drone.set(\amp, 0.28 * ~kw_intensity, \pressure, 0.88, \tilt, rrand(190, 360));
            choir.do { |node| node.set(\amp, rrand(0.035, 0.065) * ~kw_intensity) };
            ~kw_startPulseGrid.value(0.95);
            ~kw_startArcField.value(1.0, 0.32, 2.1);
            ~kw_startBeamField.value(1.05, 2.4, 9.0);

            256.do { |i|
                if ((i % 32 == 0) and: { i > 0 }) {
                    3.do {
                        ~kw_spawnBeam.value(0.8);
                        ~kw_wait.value(rrand(0.08, 0.28));
                    };
                };
                if (0.045.coin) {
                    Synth(\kwMagneticGate, [
                        \root, rootMidi.choose.midicps * [0.5, 1].choose,
                        \rate, [9, 11, 13, 17].choose,
                        \dur, rrand(3.5, 10.0) * ~kw_timeScale.max(0.2),
                        \cut, exprand(520, 5200),
                        \amp, rrand(0.12, 0.30) * ~kw_intensity,
                        \pan, rrand(-0.9, 0.9),
                        \out, ~kw_sendBus
                    ], ~kw_sourceGroup);
                };
                ~kw_wait.value(1);
            };

            ">> [BETONMEMBRAN] V. blackout / afterimage".postln;
            if (~kw_pulseRtn.notNil) { ~kw_pulseRtn.stop; ~kw_pulseRtn = nil };
            if (~kw_arcRtn.notNil) { ~kw_arcRtn.stop; ~kw_arcRtn = nil };
            if (~kw_beamRtn.notNil) { ~kw_beamRtn.stop; ~kw_beamRtn = nil };

            7.do {
                ~kw_spawnPulse.value(rrand(0.34, 0.72));
                ~kw_wait.value(rrand(4.0, 13.0));
            };

            choir.do { |node| node.set(\amp, 0.025 * ~kw_intensity) };
            drone.set(\amp, 0.11 * ~kw_intensity, \pressure, 0.34, \tilt, rrand(70, 125));
            ~kw_master.set(\delayAmp, 0.48, \revMix, 0.68);

            96.do { |i|
                if ((i % 24 == 0) and: { 0.5.coin }) { ~kw_spawnArc.value(0.22) };
                ~kw_wait.value(1);
            };

            choir.do { |node| ~kw_release.value(node) };
            ~kw_release.value(drone);
            ~kw_master.set(\amp, 0.42);

            ">> [BETONMEMBRAN] complete. Reverb tail remains; call ~kw_stop.value to clear.".postln;
        }).play(TempoClock.default);

        "".postln;
        ">> [BETONMEMBRAN] started.".postln;
        ">>    Full duration at ~kw_timeScale=1.0: roughly 12-14 minutes.".postln;
        ">>    Rehearsal: set ~kw_timeScale=0.18 before evaluation.".postln;
        ">>    Stop: ~kw_stop.value".postln;
        "".postln;
    };
});
)
