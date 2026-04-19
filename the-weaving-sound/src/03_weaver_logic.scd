// =============================================================
//  THE WEAVING SOUND — src/03_weaver_logic.scd
//
//  The Conductor: an autonomous state machine that drives all
//  sonic events. Never repeats. Breathes over hours.
//
//  Phases (cyclic, with randomised durations and transitions):
//    VOID       — near-silence; the drone alone breathes
//    EMERGENCE  — granular mist rises; plucks gain frequency
//    WEAVING    — all voices; dub pulse; glitch clusters
//    CHAOS      — attractor barrage; accelerated pulse; peak
//    COLLAPSE   — everything dissolves; silence reclaimed
//
//  Exposes ~startWeaver, called from main.scd after FX routing
//  is confirmed active.
//
//  All .wait calls live inside Routines (TempoClock.default).
//  Race conditions are impossible: main.scd calls s.sync before
//  ~startWeaver.value — all SynthDefs and buses are guaranteed.
// =============================================================

(

// ─────────────────────────────────────────────────────────────
//  GLOBAL SYNTH REFERENCES
//  Gate-sustained voices persist across phase transitions.
//  Nil when not active; released via gate=0, freed by doneAction:2.
// ─────────────────────────────────────────────────────────────
~wv_drone  = nil;  // void_drone    (one active at a time)
~wv_pad    = nil;  // void_pad      (one active at a time)
~wv_cloud  = nil;  // granular_cloud (one active at a time)

// ─────────────────────────────────────────────────────────────
//  CONCURRENT ROUTINE HANDLES
//  Pulse and glitch routines run in parallel with the master loop.
// ─────────────────────────────────────────────────────────────
~wv_pulseRtn  = nil;
~wv_glitchRtn = nil;

// ─────────────────────────────────────────────────────────────
//  PITCH VOCABULARY
//  Sub-bass fundamentals and A-minor flavoured melody register.
//  Frequencies chosen by .choose in the Conductor — not scale-locked,
//  more like modal gravity than strict tonality.
// ─────────────────────────────────────────────────────────────
~wv_bassHz  = [29.14, 32.70, 36.71, 41.20, 43.65, 49.00, 55.00];
~wv_meldHz  = [110.0, 130.8, 146.8, 164.8, 174.6, 196.0,
               220.0, 246.9, 261.6, 293.7, 329.6, 369.9];


// ─────────────────────────────────────────────────────────────
//  HELPER FUNCTIONS
// ─────────────────────────────────────────────────────────────

// Gracefully release a gate-sustained synth (nil-safe)
~wv_release = { |ref|
    if (ref.notNil) { ref.set(\gate, 0) };
};

// Spawn a single thread_pluck (one-shot, self-frees)
~wv_spawnPluck = {
    Synth(\thread_pluck, [
        \freq,  ~wv_meldHz.choose * [0.5, 1.0, 2.0].choose,
        \amp,   rrand(0.07, 0.22),
        \decay, rrand(2.5, 9.0),
        \pan,   rrand(-0.85, 0.85),
        \coef,  rrand(0.20, 0.52),
        \out,   ~sendBus
    ], ~sourceGroup);
};

// Spawn a single chaos_glitch event (one-shot, self-frees)
~wv_spawnGlitch = {
    Synth(\chaos_glitch, [
        \amp, rrand(0.18, 0.56),
        \pan, rrand(-1.0, 1.0),
        \out, ~sendBus
    ], ~sourceGroup);
};

// Start rhythmic kick-pulse Routine at a given BPM.
// Pattern: 4/4 with kick on beat 1, beat 3 with 72 % probability.
// Each 1/4-note step is humanised by ±0.9 % micro-timing.
~wv_startPulse = { |bpm = 120|
    var beatDur;
    beatDur = 60.0 / bpm;

    ~wv_pulseRtn = Routine({
        loop {
            4.do { |beat|
                var doKick;
                doKick = (beat == 0) or: ((beat == 2) and: { 0.72.coin });
                if (doKick) {
                    Synth(\void_pulse, [
                        \freq,  rrand(42.0, 54.0),
                        \amp,   rrand(0.28, 0.50),
                        \decay, rrand(0.55, 1.00),
                        \out,   ~sendBus
                    ], ~sourceGroup);
                };
                // Humanise: each step is slightly early or late
                (beatDur * (1.0 + rrand(-0.009, 0.009))).wait;
            };
        };
    }).play(TempoClock.default);
};

// Stop the pulse Routine safely
~wv_stopPulse = {
    if (~wv_pulseRtn.notNil) {
        ~wv_pulseRtn.stop;
        ~wv_pulseRtn = nil;
    };
};

// Start chaos glitch barrage (Routine fires glitches continuously)
~wv_startGlitch = {
    ~wv_glitchRtn = Routine({
        loop {
            ~wv_spawnGlitch.value;
            rrand(0.03, 0.32).wait;
        };
    }).play(TempoClock.default);
};

// Stop the glitch barrage safely
~wv_stopGlitch = {
    if (~wv_glitchRtn.notNil) {
        ~wv_glitchRtn.stop;
        ~wv_glitchRtn = nil;
    };
};


// ─────────────────────────────────────────────────────────────
//  MASTER WEAVER — deferred entry point
//  Called from main.scd after all setup is confirmed.
// ─────────────────────────────────────────────────────────────
~startWeaver = {

    ~weaverMaster = Routine({

        var phase, dur, elapsed, waitTime, weaveBpm;

        phase = \void;

        // Brief initial silence: let the reverb tail decay before first sound
        2.5.wait;

        // ── MAIN PHASE LOOP ────────────────────────────────────
        loop {

            (">> [WEAVER] ═══ Phase: " ++ phase ++ " ═══").postln;

            // ══════════════════════════════════════════════════
            //  VOID
            //  Almost nothing. A single drone breathes in the dark.
            //  Sparse plucks surface like light through deep water.
            // ══════════════════════════════════════════════════
            case
            { phase == \void } {

                dur     = rrand(90.0, 240.0);
                elapsed = 0.0;

                (">>   duration: " ++ dur.round(0.1) ++ "s").postln;

                // Release any lingering drone from a previous cycle
                // (prevents node leak when WEAVING transitions directly to VOID)
                ~wv_release.value(~wv_drone); ~wv_drone = nil;

                // Start the sub-bass drone quietly
                ~wv_drone = Synth(\void_drone, [
                    \freq,       ~wv_bassHz.choose,
                    \amp,        0.10,
                    \modFreq,    rrand(0.03, 0.06),
                    \filterFreq, rrand(60, 130),
                    \out,        ~sendBus
                ], ~sourceGroup);

                // Sparse plucks: one every 18–55 seconds, 72 % probability
                while { elapsed < dur } {
                    waitTime = rrand(18.0, 55.0);
                    waitTime.wait;
                    elapsed = elapsed + waitTime;

                    if ((elapsed < dur) and: { 0.72.coin }) {
                        ~wv_spawnPluck.value;
                    };
                };

                phase = \emergence;
            }

            // ══════════════════════════════════════════════════
            //  EMERGENCE
            //  The drone stirs — a granular mist rises from nothing.
            //  Plucks become more frequent. Proto-glitches appear.
            // ══════════════════════════════════════════════════
            { phase == \emergence } {

                dur     = rrand(60.0, 120.0);
                elapsed = 0.0;

                (">>   duration: " ++ dur.round(0.1) ++ "s").postln;

                // Drone intensifies slightly
                if (~wv_drone.notNil) {
                    ~wv_drone.set(\amp, 0.17, \modFreq, rrand(0.05, 0.09));
                };

                // Granular cloud starts at minimal density and volume
                ~wv_cloud = Synth(\granular_cloud, [
                    \amp,        0.04,
                    \density,    rrand(3, 7),
                    \grainDur,   rrand(0.07, 0.22),
                    \centerFreq, rrand(280, 600),
                    \freqSpread, rrand(1.4, 2.2),
                    \out,        ~sendBus
                ], ~sourceGroup);

                // Plucks every 7–22 seconds now
                while { elapsed < dur } {
                    waitTime = rrand(7.0, 22.0);
                    waitTime.wait;
                    elapsed = elapsed + waitTime;

                    if (elapsed < dur) { ~wv_spawnPluck.value };

                    // Occasional early glitch (18 % chance)
                    if (0.18.coin) { ~wv_spawnGlitch.value };
                };

                // Cloud gains density before weaving begins
                if (~wv_cloud.notNil) {
                    ~wv_cloud.set(
                        \density,    rrand(8, 14),
                        \amp,        0.10,
                        \centerFreq, rrand(400, 900)
                    );
                };

                phase = \weaving;
            }

            // ══════════════════════════════════════════════════
            //  WEAVING
            //  The loom runs at full speed. The dub pulse emerges.
            //  All voices interlock. Glitch clusters spray at random.
            // ══════════════════════════════════════════════════
            { phase == \weaving } {

                dur      = rrand(120.0, 300.0);
                elapsed  = 0.0;
                weaveBpm = rrand(118.0, 126.0);

                (">>   duration: " ++ dur.round(0.1) ++ "s  bpm: " ++ weaveBpm.round(0.1)).postln;

                if (~wv_drone.notNil) {
                    ~wv_drone.set(\amp, 0.20, \filterFreq, rrand(120, 260));
                };

                // Add the shimmer pad
                ~wv_pad = Synth(\void_pad, [
                    \freq,   ~wv_bassHz.choose * 2.0,
                    \amp,    0.07,
                    \detune, rrand(0.008, 0.018),
                    \out,    ~sendBus
                ], ~sourceGroup);

                // Launch dub-techno pulse in a concurrent Routine
                ~wv_startPulse.value(weaveBpm);

                // Main weaving loop: plucks, glitch clusters, cloud evolution
                while { elapsed < dur } {
                    waitTime = rrand(2.5, 11.0);
                    waitTime.wait;
                    elapsed = elapsed + waitTime;

                    // Melodic pluck (65 % chance)
                    if ((elapsed < dur) and: { 0.65.coin }) {
                        ~wv_spawnPluck.value;
                    };

                    // Glitch cluster (45 % chance): 1–4 events with short gaps
                    if (0.45.coin) {
                        rrand(1, 4).do {
                            ~wv_spawnGlitch.value;
                            rrand(0.02, 0.13).wait;
                        };
                    };

                    // Evolve granular cloud parameters (25 % chance)
                    if ((elapsed < dur) and: { 0.25.coin } and: { ~wv_cloud.notNil }) {
                        ~wv_cloud.set(
                            \density,    rrand(10, 26),
                            \amp,        rrand(0.08, 0.21),
                            \centerFreq, rrand(280, 1400)
                        );
                    };
                };

                // Wind down before leaving this phase
                ~wv_stopPulse.value;
                ~wv_release.value(~wv_cloud);  ~wv_cloud = nil;
                ~wv_release.value(~wv_pad);    ~wv_pad   = nil;

                if (~wv_drone.notNil) { ~wv_drone.set(\amp, 0.12) };

                // 65 % chance to rest in void; 35 % chance to escalate to chaos
                phase = [\void, \chaos].wchoose([0.65, 0.35]);
            }

            // ══════════════════════════════════════════════════
            //  CHAOS
            //  The Lorenz attractor escapes. Glitch walls.
            //  Pulse accelerates. Temporal grammar dissolves.
            // ══════════════════════════════════════════════════
            { phase == \chaos } {

                dur = rrand(25.0, 75.0);
                (">>   duration: " ++ dur.round(0.1) ++ "s").postln;

                // Push the drone louder and brighter
                if (~wv_drone.notNil) {
                    ~wv_drone.set(\amp, 0.28, \filterFreq, rrand(200, 700));
                };

                // Rapid-fire glitch barrage (concurrent)
                ~wv_startGlitch.value;

                // Faster, harder pulse in chaos
                ~wv_startPulse.value(rrand(130.0, 155.0));

                dur.wait;

                // Stop both concurrent routines
                ~wv_stopGlitch.value;
                ~wv_stopPulse.value;

                // Drone recedes
                if (~wv_drone.notNil) {
                    ~wv_drone.set(\amp, 0.11, \filterFreq, rrand(70, 150));
                };

                phase = \collapse;
            }

            // ══════════════════════════════════════════════════
            //  COLLAPSE
            //  All threads unravel. Silence reclaims its territory.
            //  The void reasserts itself.
            // ══════════════════════════════════════════════════
            { phase == \collapse } {

                ">> [WEAVER] Collapsing — the void reclaims...".postln;

                // Safety: stop any lingering concurrent routines
                ~wv_stopGlitch.value;
                ~wv_stopPulse.value;

                // Release remaining sustain synths
                ~wv_release.value(~wv_cloud);  ~wv_cloud = nil;
                ~wv_release.value(~wv_pad);    ~wv_pad   = nil;

                // Drone fades on its own long release envelope
                ~wv_release.value(~wv_drone);
                ~wv_drone = nil;

                // Wait for envelopes to decay and silence to settle
                rrand(18.0, 42.0).wait;

                phase = \void;
            }

            // ══════════════════════════════════════════════════
            //  SAFETY NET — should never be reached
            // ══════════════════════════════════════════════════
            { true } {
                ">> [WEAVER] Unknown phase — resetting to void.".postln;
                ~wv_stopGlitch.value;
                ~wv_stopPulse.value;
                3.0.wait;
                phase = \void;
            };

        }; // end loop

    }).play(TempoClock.default);

    ">> [03_weaver_logic] Master Routine started on TempoClock.".postln;
};


">> [03_weaver_logic] ~startWeaver defined.".postln;
">> [03_weaver_logic] Call ~startWeaver.value after FX routing is active.".postln;

) // end block
