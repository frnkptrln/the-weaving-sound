// Shared phrase mapping for live playback and the offline listening study.
// All times are seconds, independent of other pieces' TempoClock settings.
(
~bindingChord = [48, 55, 60, 63, 67];
~bindingFrame = { |values|
    var macros = ~weavingMacros.(values);
    (
        // Zero motion really is a chord: every onset shares one timestamp.
        onsetGap: (macros[\motion].linexp(0, 1, 0.012, 0.32) - 0.012)
            * macros[\density].linexp(0, 1, 1.5, 0.55),
        hold: macros[\space].linlin(0, 1, 0.25, 2.8),
        rest: macros[\density].linexp(0, 1, 2.8, 0.45),
        width: macros[\space].linlin(0, 1, 0.1, 0.7),
        cutoff: macros[\brightness].linexp(0, 1, 350, 7200),
        resonance: macros[\tension].linlin(0, 1, 0.12, 0.55),
        drive: macros[\grit].linlin(0, 1, 1.0, 3.2)
    )
};
~bindingVoiceArgs = { |note, index, frame|
    [
        \freq, note.midicps,
        \cutoff, frame[\cutoff],
        \res, frame[\resonance],
        \drive, frame[\drive],
        \rel, frame[\hold],
        \amp, 0.09,
        \pan, index.linlin(0, ~bindingChord.size - 1,
            frame[\width].neg, frame[\width])
    ]
};
~bindingMotionAt = { |seconds|
    if(seconds < 6) { 0.0 } {
        if(seconds < 24) { seconds.linlin(6, 24, 0, 1) } {
            if(seconds < 32) { 1.0 } {
                if(seconds < 50) { seconds.linlin(32, 50, 1, 0) } { 0.0 }
            }
        }
    }
};
)
