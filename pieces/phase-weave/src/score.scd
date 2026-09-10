// A finite score; loading this file neither boots a server nor starts playback.
(
{
    var root = thisProcess.nowExecutingPath.dirname.dirname.dirname.dirname;
    var duration = 72.0, events, nodeID = 1000, metadata, room;
    var notes = [57, 64, 69, nil, 67, 64, nil, 60];
    var accents = [0.64, 0.38, 0.46, 0, 0.52, 0.36, 0, 0.42];
    var phaseAt, levelAt, addNote;

    (root +/+ "core/metadata.scd").load;
    (root +/+ "engines/physical.scd").load;
    metadata = ~weavingPiece.((
        name: "phase-weave",
        description: "Two string loops lose and recover a shared pulse",
        engines: [\eng_physical_pluck],
        tags: [\phasing, \physical_modelling, \rhythm],
        mode: \finite_study,
        duration: duration,
        status: \study
    ));

    room = SynthDef(\phase_weave_room, {
        arg in = 2, out = 0, gate = 1;
        var dry = In.ar(in, 2), wet, release;
        wet = FreeVerb2.ar(dry[0], dry[1], 0.18, 0.54, 0.58);
        // The room decays before this gentle final fade. Keep the node alive
        // at zero until the explicit cleanup, leaving actual digital silence.
        release = EnvGen.kr(Env.asr(0.01, 1, 1.2), gate);
        Out.ar(out, Limiter.ar(LeakDC.ar(wet) * 4.0, 0.88) * release);
    });

    events = [
        [0.0, [\d_recv, SynthDescLib.global.at(\eng_physical_pluck).def.asBytes]],
        [0.0, [\d_recv, room.asBytes]],
        [0.05, [\s_new, \phase_weave_room, 100, 1, 1, \in, 2, \out, 0]]
    ];

    // Smooth time displacement, sampled at each note: the left pulse stays
    // fixed while the right loop slows, holds a half-loop offset, and catches up.
    phaseAt = { |time|
        if(time < 8) { 0.0 } {
            if(time < 27) {
                1.5 * (1 - cos(pi * time.linlin(8, 27, 0, 1))) * 0.5
            } {
                if(time < 35) { 1.5 } {
                    if(time < 55) {
                        1.5 * (1 + cos(pi * time.linlin(35, 55, 0, 1))) * 0.5
                    } { 0.0 }
                }
            }
        }
    };
    levelAt = { |time|
        if(time < 9) { time.linlin(2, 9, 0.56, 0.84) } {
            if(time < 29) { time.linlin(9, 29, 0.84, 1.14) } {
                if(time < 43) { 1.06 } {
                    time.linlin(43, 62, 1.06, 0.52)
                }
            }
        }
    };
    addNote = { |time, note, amp, pan, decay = 1.15|
        events = events.add([time, [\s_new, \eng_physical_pluck,
            nodeID, 0, 1, \out, 2, \freq, note.midicps,
            \amp, amp, \pan, pan, \decay, decay,
            \coef, if(pan < 0) { 0.25 } { 0.29 }]]);
        nodeID = nodeID + 1;
    };

    19.do { |cycle|
        // Whole-phrase breaths expose the ringing strings without altering
        // either loop's pitch order. Their placement follows the nominal clock.
        if(#[5, 12].includes(cycle).not) {
            notes.do { |note, step|
                if(note.notNil) {
                    var time = 2.0 + (cycle * 3.0) + (step * 0.375);
                    var amp = accents[step] * levelAt.(time);
                    var decay = if(cycle >= 16) { 1.45 } { 1.15 };
                    addNote.(time, note, amp, -0.48, decay);
                    addNote.(time + phaseAt.(time), note, amp * 0.94, 0.48, decay);
                };
            };
        };
    };

    // An open fifth remains after the loops reunite; its quiet answer is the
    // last excitation at 62 seconds. No new voices enter during the room tail.
    addNote.(60.0, 57, 0.30, -0.32, 1.7);
    addNote.(60.0, 64, 0.28, 0.32, 1.7);
    addNote.(62.0, 69, 0.17, 0.0, 1.25);
    events = events ++ [
        [68.2, [\n_set, 100, \gate, 0]],
        // Explicitly free the persistent room after its tail and silent hold.
        [duration - 0.02, [\n_free, 100]],
        [duration, [0]]
    ];

    (name: "phase-weave", duration: duration, score: Score(events), metadata: metadata)
}.value
)
