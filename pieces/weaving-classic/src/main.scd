// =============================================================
//  THE WEAVING SOUND — src/main.scd
//
//  Master boot process.
//
//  Loading order and synchronisation:
//    1. s.options configured before server boot
//    2. s.waitForBoot ensures server is running
//    3. fork enters a Routine context for .wait / s.sync
//    4. All three source files are loaded (SynthDefs + functions)
//    5. s.sync: BLOCKS until scsynth has compiled all SynthDefs
//    6. ~startFxRouting creates buses, groups, and the FX synth
//    7. s.sync: BLOCKS until groups and FX node are confirmed
//    8. ~startWeaver launches the generative conductor Routine
//
//  To run headlessly:  ./start.sh
//  To run in IDE:      open this file, boot server, Ctrl+A, Ctrl+Enter
// =============================================================

(

var projectDir;

// Resolve the directory containing this file — works both headless
// (sclang path arg) and from the IDE (thisProcess.nowExecutingPath).
projectDir = thisProcess.nowExecutingPath.dirname;


// ─────────────────────────────────────────────────────────────
//  SERVER OPTIONS
//  Configured before boot; ignored if server is already running.
// ─────────────────────────────────────────────────────────────

// 64 MB synthesis memory — comfortable headroom for granular buffers
s.options.memSize             = 65536;

// 1024 buffer slots for any future buffer-based extensions
s.options.numBuffers          = 1024;

// Extra audio buses for flexible future routing
s.options.numAudioBusChannels = 128;

// 2 output channels — stereo hardware output
s.options.numOutputBusChannels = 2;

// 48 kHz: standard for PipeWire / modern audio stacks.
// Set to 0 to inherit the system device rate (e.g. 44100 Hz).
// Must match the PipeWire / JACK sample rate or SC will warn.
s.options.sampleRate          = 48000;

// 128-sample block: ~2.67 ms at 48 kHz; good balance of latency/CPU.
// Raise to 256 for older hardware or when xruns occur.
s.options.blockSize           = 128;

// Allow up to 4096 active synth nodes simultaneously
s.options.maxNodes            = 4096;

// Print the server address to the post window on boot
s.options.verbosity           = 0;   // 0 = normal, -1 = quiet, 1 = verbose


// ─────────────────────────────────────────────────────────────
//  BOOT AND LOAD
// ─────────────────────────────────────────────────────────────

s.waitForBoot({

    "".postln;
    "╔═══════════════════════════════════════╗".postln;
    "║   T H E   W E A V I N G   S O U N D  ║".postln;
    "║            initialising ...          ║".postln;
    "╚═══════════════════════════════════════╝".postln;
    "".postln;

    // fork: opens a Routine context so we can use s.sync and .wait
    fork {

        // ── Step 1: Define all SynthDefs ───────────────────────
        // .load evaluates each file synchronously on the sclang side,
        // queueing SynthDef messages to the server.
        (projectDir +/+ "01_synthdefs.scd").load;
        (projectDir +/+ "02_fx_routing.scd").load;
        (projectDir +/+ "03_weaver_logic.scd").load;

        // s.sync: suspend this Routine until scsynth acknowledges
        // that ALL pending /d_recv messages have been processed.
        // This guarantees every SynthDef exists before we try to
        // instantiate a Synth.
        s.sync;
        ">> [main] All SynthDefs compiled on scsynth.".postln;


        // ── Step 2: Activate FX routing ────────────────────────
        // ~startFxRouting creates ~sendBus, ~sourceGroup, ~fxGroup,
        // and instantiates ~masterFxSynth on the server.
        ~startFxRouting.value;

        // s.sync again: confirm groups and FX node are live
        // before source synths try to target them.
        s.sync;
        ">> [main] FX chain active.".postln;


        // ── Step 3: Launch the generative conductor ────────────
        // ~startWeaver starts the master Routine on TempoClock.
        // From this point the piece runs autonomously.
        ~startWeaver.value;


        // ── Boot complete ──────────────────────────────────────
        "".postln;
        "╔═══════════════════════════════════════╗".postln;
        "║   T H E   S O U N D   B E G I N S    ║".postln;
        "║          T O   W E A V E             ║".postln;
        "╚═══════════════════════════════════════╝".postln;
        "".postln;
        ">> Server: % SynthDefs compiled / % synths active."
            .format(s.numSynthdefs, s.numSynths).postln;
        ">> FX bus index: %".format(~sendBus.index).postln;
        ">> Ctrl+C (headless) or Cmd+. (IDE) to stop.".postln;
        "".postln;

    }; // end fork

}); // end s.waitForBoot

) // end block
