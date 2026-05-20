// =============================================================
//  THE WEAVING SOUND — src/01_synthdefs.scd
//
//  Six SynthDef definitions: the raw sonic material.
//  Loaded by main.scd; instantiation is deferred until after s.sync.
//
//  SynthDefs defined here:
//    1. void_drone     — sub-bass formant drone (gate-sustained)
//    2. void_pad       — shimmer pad, 6 detuned partials (gate-sustained)
//    3. void_pulse     — dub-techno sub-kick (one-shot)
//    4. thread_pluck   — Karplus-Strong physical model (one-shot)
//    5. chaos_glitch   — Lorenz attractor micro-event (one-shot, needs sc3-plugins)
//    6. granular_cloud — GrainNoise texture (gate-sustained)
// =============================================================

(

// ─────────────────────────────────────────────────────────────
//  1. VOID DRONE
//  An extremely deep, slowly morphing sub-bass foundation.
//  Multi-partial sine bed filtered through animated formant
//  resonators — like a pipe organ buried under concrete.
// ─────────────────────────────────────────────────────────────
SynthDef(\void_drone, {
    arg freq = 35, amp = 0.25, gate = 1, out = 0,
        modFreq = 0.05, filterFreq = 160;

    var lfoA, lfoB, lfoC, sig, formanted, env;

    // Three independent slow LFOs for organic modulation
    lfoA = SinOsc.kr(modFreq,            0,      0.12, 1.0);
    lfoB = SinOsc.kr(modFreq * 1.37,     pi/3,   0.08, 1.0);
    lfoC = LFNoise2.kr(modFreq * 0.5).range(0.96, 1.04);

    // Multi-partial sine stack — fundamental through 3rd harmonic
    sig = Mix([
        SinOsc.ar(freq * lfoA,                0,  0.45),
        SinOsc.ar(freq * 2.0 * lfoB,          0,  0.25),
        SinOsc.ar(freq * 3.0 * lfoA * lfoB,   0,  0.12),
        SinOsc.ar(freq * 0.5 * lfoC,          0,  0.30),
        LFSaw.ar( freq,                        0,  0.04)
    ]) * 0.18;

    // Formant filtering: three resonators sweep independently
    formanted = Mix([
        Resonz.ar(sig,
            filterFreq * LFNoise2.kr(0.07).exprange(0.5, 2.2),
            0.07),
        Resonz.ar(sig,
            filterFreq * 2.8 * LFNoise2.kr(0.04).exprange(0.8, 1.6),
            0.08),
        RLPF.ar(sig,
            filterFreq * LFNoise2.kr(0.11).exprange(0.3, 2.8),
            0.35)
    ]) * 0.55;

    // Long attack and release for glacial transitions
    env = EnvGen.kr(Env.asr(8.0, 1.0, 14.0), gate, doneAction: 2);

    // Subtle auto-pan (very slow, barely perceptible — spatial breathing)
    Out.ar(out,
        Pan2.ar(formanted * env * amp,
            SinOsc.kr(0.018).range(-0.18, 0.18))
    );
}).add;


// ─────────────────────────────────────────────────────────────
//  2. VOID PAD
//  A shimmering spectral haze: six detuned sine partials,
//  each amplitude-modulated at a different rate.
//  Occupies the upper harmonic register above the drone.
// ─────────────────────────────────────────────────────────────
SynthDef(\void_pad, {
    arg freq = 55, amp = 0.12, gate = 1, out = 0, detune = 0.012;

    var sigs, sig, env;

    // Build array at SynthDef compile time; Rand() is per-instance at runtime
    sigs = Array.fill(6, { |i|
        var f, rate;
        // Alternate above/below fundamental
        f    = freq * (1.0 + (i * detune * (i.odd.if(1, -1))));
        rate = Rand(0.03, 0.17);
        SinOsc.ar(f) * LFNoise2.kr(rate).range(0.25, 1.0)
    });

    sig = Mix(sigs) * (1.0 / 6.0);

    // Subtle amplitude modulation shimmer
    sig = sig + (LFNoise2.ar(0.9) * sig * 0.045);

    env = EnvGen.kr(Env.asr(12.0, 1.0, 16.0), gate, doneAction: 2);

    Out.ar(out,
        Pan2.ar(sig * amp * env,
            SinOsc.kr(0.023).range(-0.28, 0.28))
    );
}).add;


// ─────────────────────────────────────────────────────────────
//  3. VOID PULSE
//  A dub-techno sub-kick: steep pitch envelope from 5× to 0.85×,
//  plus a short click transient for presence through the bass mud.
// ─────────────────────────────────────────────────────────────
SynthDef(\void_pulse, {
    arg freq = 48, amp = 0.55, out = 0, decay = 0.75, clickAmt = 0.28;

    var pitchEnv, clickEnv, sig, click, env;

    // Pitch sweeps from 5× fundamental down quickly
    pitchEnv = EnvGen.kr(
        Env([freq * 5.0, freq * 1.2, freq * 0.85],
            [0.018, decay * 0.9],
            \exp)
    );
    sig = SinOsc.ar(pitchEnv);

    // High-pass click for transient definition
    clickEnv = EnvGen.kr(Env.perc(0.0001, 0.005));
    click    = HPF.ar(WhiteNoise.ar(clickAmt), 3000) * clickEnv;

    // Amplitude envelope: punchy with exponential decay
    env = EnvGen.kr(Env.perc(0.001, decay, 1.0, -4.5), doneAction: 2);

    Out.ar(out, ((sig + click) * amp * env).dup);
}).add;


// ─────────────────────────────────────────────────────────────
//  4. THREAD PLUCK
//  Karplus-Strong physical modelling: the string that emerges
//  from the void and vanishes. Pitch drawn from an A-minor
//  vocabulary by the Conductor. Warm wood/gut character.
// ─────────────────────────────────────────────────────────────
SynthDef(\thread_pluck, {
    arg freq = 220, amp = 0.25, out = 0,
        decay = 4.0, pan = 0, coef = 0.32;

    var trig, sig, env;

    // Single impulse trigger at birth
    trig = Impulse.ar(0);

    // Pluck.ar: Karplus-Strong waveguide synthesis
    //   maxdelaytime = 0.2 s supports frequencies down to ~5 Hz
    sig = Pluck.ar(
        WhiteNoise.ar(0.4),
        trig,
        0.2,              // maxdelaytime
        freq.reciprocal,  // delay time = period of desired pitch
        decay,
        coef              // reflection coefficient — higher = brighter
    );

    // Low-pass for warmth: attenuate upper partials
    sig = LPF.ar(sig, freq * 5.5);

    // Exponential-decay amplitude envelope matches physical behaviour
    env = EnvGen.kr(Env.perc(0.001, decay * 1.8, 1.0, -3.0), doneAction: 2);

    Out.ar(out, Pan2.ar(sig * amp * env, pan));
}).add;


// ─────────────────────────────────────────────────────────────
//  5. CHAOS GLITCH
//  The Lorenz strange attractor (σ=10, ρ=28, β=8/3) drives
//  pitch — unpredictable, short, violent micro-events.
//
//  *** Requires sc3-plugins (LorenzL UGen) ***
//
//  LorenzL.ar(freq, s, r, b, h, xi, yi, zi)
//    freq  — integration rate (Hz); higher = faster chaos evolution
//    s,r,b — classic Lorenz parameters
//    h     — Euler step size (smaller = more accurate, slower)
//    xi,yi,zi — initial conditions (per-instance random via Rand())
// ─────────────────────────────────────────────────────────────
SynthDef(\chaos_glitch, {
    arg amp = 0.45, out = 0, pan = 0;

    var dur, chaos, freq, sig, env;

    // Per-instance random duration (evaluated server-side at spawn time)
    dur   = ExpRand(0.04, 0.38);

    // Lorenz attractor oscillator
    chaos = LorenzL.ar(
        SampleRate.ir * 0.5,  // integration rate: half Nyquist
        10.0,                 // sigma
        28.0,                 // rho
        2.667,                // beta (≈ 8/3)
        0.02,                 // step size h
        Rand(-0.5, 0.5),      // xi: random initial condition
        Rand(-0.5, 0.5),      // yi
        Rand(-0.5, 0.5)       // zi
    );

    // Map attractor output (approx. –30…+30) to frequency range
    freq = chaos.linexp(-30, 30, 90, 7200);

    // Sinusoid at chaotic frequency, amplitude-modulated by noise
    sig  = SinOsc.ar(freq) * LFNoise0.ar(IRand(80, 600));

    // High-pass resonant filter to emphasise chaotic character
    sig  = RHPF.ar(sig, ExpRand(180, 3800), 0.15) * 0.4;

    env = EnvGen.kr(Env.perc(0.001, dur), doneAction: 2);
    Out.ar(out, Pan2.ar(sig * amp * env, pan));
}).add;


// ─────────────────────────────────────────────────────────────
//  6. GRANULAR CLOUD
//  GrainNoise with per-grain random panning and band-pass
//  filtering whose centre frequency is swept by nested LFOs.
//  Dissolves the boundary between noise and texture.
// ─────────────────────────────────────────────────────────────
SynthDef(\granular_cloud, {
    arg amp = 0.18, out = 0, gate = 1,
        density = 10, grainDur = 0.12,
        centerFreq = 700, freqSpread = 1.8;

    var trig, grainDurMod, panMod, sig, env;

    // Regular trigger; density controls grains-per-second
    trig = Impulse.ar(density);

    // Per-grain duration and pan vary slowly around the base values
    grainDurMod = LFNoise2.kr(0.6).range(grainDur * 0.4, grainDur * 1.6);
    panMod      = LFNoise2.kr(0.4);

    // Stereo grain cloud (numChannels = 2)
    sig = GrainNoise.ar(2, trig, grainDurMod, panMod);

    // Band-pass filter whose centre frequency wanders over time
    //   Outer LFNoise1 modulates the inner LFNoise2's speed
    sig = BPF.ar(sig,
        LFNoise2.kr(
            LFNoise1.kr(0.15).exprange(0.05, 0.55)
        ).exprange(centerFreq / freqSpread, centerFreq * freqSpread),
        0.35
    );

    // Long attack and release to fade cloud in/out organically
    env = EnvGen.kr(Env.asr(6.0, 1.0, 9.0), gate, doneAction: 2);

    Out.ar(out, sig * amp * env);
}).add;


">> [01_synthdefs] All 6 SynthDefs defined — void_drone, void_pad, void_pulse,".postln;
">>               thread_pluck, chaos_glitch, granular_cloud.".postln;

) // end block
