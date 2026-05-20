// =============================================================
//  THE WEAVING SOUND — src/02_fx_routing.scd
//
//  Global FX chain: tape delay → giant reverb → saturation → limiter.
//  Defines the \fx_master SynthDef and exposes ~startFxRouting,
//  a deferred setup function called by main.scd AFTER s.sync.
//
//  Signal flow:
//    All source synths write to ~sendBus  (Bus.audio stereo)
//    ~masterFxSynth reads ~sendBus, processes, and writes to Out 0
//
//  Node ordering is enforced via Groups:
//    ~sourceGroup  →  ~fxGroup  (fx always renders after sources)
// =============================================================

(

// ─────────────────────────────────────────────────────────────
//  FX MASTER SYNTHDEF
//  One node handles the entire chain to avoid inter-bus routing
//  complexity: tape echo → reverb → harmonic warmth → limiter.
// ─────────────────────────────────────────────────────────────
SynthDef(\fx_master, {
    arg in         = 0,
        out        = 0,
        // Tape delay parameters
        delayTime  = 0.375,  // 1/8 note at ~120 bpm — classic dub off-beat
        delayFb    = 0.38,   // feedback coefficient
        delayAmp   = 0.42,   // wet delay level
        // Reverb parameters
        revMix     = 0.52,   // dry/wet balance
        revRoom    = 0.93,   // room size (0..1)
        revDamp    = 0.48,   // high-frequency damping
        // Master
        masterAmp  = 0.88;

    var sig, dry, wowFlutter, delayed, wet, reverbed;

    // Read stereo signal from the shared send bus
    sig = In.ar(in, 2);
    dry = sig;

    // ── Tape Echo ──────────────────────────────────────────────
    // CombC: cubic interpolation delay (smoothest for musical use)
    // LFNoise1 on delayTime = "wow" pitch flutter (analogue tape wow)
    wowFlutter = LFNoise1.kr(0.22).range(-0.004, 0.004);
    delayed    = CombC.ar(
        sig,
        2.0,                              // maxdelaytime (s)
        delayTime + wowFlutter,           // actual delay time with flutter
        delayTime * 9.0 * delayFb         // decay time: controls feedback density
    ) * delayAmp;

    // Low-pass on delay repeats — simulates tape head frequency loss
    delayed = LPF.ar(delayed, 3100);

    // Mix dry + delayed before reverb
    wet = dry + delayed;

    // ── Giant Reverb ───────────────────────────────────────────
    // FreeVerb2: true stereo reverb (separate L/R input channels)
    reverbed = FreeVerb2.ar(
        wet[0], wet[1],
        revMix,   // mix: 0 = dry, 1 = fully wet
        revRoom,  // room size
        revDamp   // high-freq damping — higher = darker reverb tail
    );

    // ── Harmonic Warmth ────────────────────────────────────────
    // tanh soft saturation: even-order harmonics, analogue warmth
    // Drive slightly above unity, then attenuate back
    reverbed = tanh(reverbed * 1.15) * 0.9;

    // ── Brickwall Limiter ──────────────────────────────────────
    // Protects speakers and DAC from transient overloads.
    // lookahead = 12 ms, ceiling = –0.27 dBFS
    reverbed = Limiter.ar(reverbed * masterAmp, 0.97, 0.012);

    Out.ar(out, reverbed);
}).add;


// ─────────────────────────────────────────────────────────────
//  DEFERRED SETUP FUNCTION
//  Called from main.scd after s.sync confirms \fx_master
//  has been compiled on the server.
//  Creates: ~sendBus, ~sourceGroup, ~fxGroup, ~masterFxSynth
// ─────────────────────────────────────────────────────────────
~startFxRouting = {

    // Stereo audio bus: the single point all source synths write to.
    // Bus.audio allocation is client-side (no server round-trip needed).
    ~sendBus = Bus.audio(s, 2);

    // Source group: contains all voice synths.
    // Created first — will render before the FX group.
    ~sourceGroup = Group.new(s);

    // FX group: placed after ~sourceGroup in the node tree.
    // Group.after guarantees it always processes after sources.
    ~fxGroup = Group.after(~sourceGroup);

    // Instantiate master FX synth, reading from ~sendBus, output to 0.
    ~masterFxSynth = Synth(\fx_master, [
        \in,        ~sendBus,
        \out,       0,
        \delayTime, 0.375,   // 1/8 note at 120 bpm
        \revRoom,   0.93,
        \revMix,    0.52
    ], ~fxGroup);

    ">> [02_fx_routing] sendBus=% | sourceGroup=% | fxGroup=% | fxSynth=%"
        .format(
            ~sendBus.index,
            ~sourceGroup.nodeID,
            ~fxGroup.nodeID,
            ~masterFxSynth.nodeID
        )
        .postln;
};


">> [02_fx_routing] \\fx_master SynthDef defined.".postln;
">> [02_fx_routing] Call ~startFxRouting.value after s.sync to activate routing.".postln;

) // end block
