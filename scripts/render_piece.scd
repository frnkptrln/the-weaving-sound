// Compile a finite score for render_piece.py; no real-time audio server is booted.
(
{
    var root = thisProcess.argv[0], name = thisProcess.argv[1];
    var scratch = thisProcess.argv[2], piece, duration;
    TempoClock.default.tempo = 1;
    piece = (root +/+ "pieces" +/+ name +/+ "src/score.scd").load;
    if(piece.isNil or: { piece[\name] != name } or: {
        piece[\score].isKindOf(Score).not
    }) { Error("Score must return its matching name and a Score").throw };
    duration = piece[\duration];
    if(duration.isNumber.not or: { duration.isNaN } or: {
        duration <= 0 or: { duration > 600 }
    }) {
        Error("Score duration must be between 0 and 600 seconds").throw;
    };
    piece[\score].score.do { |event|
        if(event[0].isNumber.not or: { event[0].isNaN } or: {
            event[0] < 0 or: { event[0] > duration }
        }) {
            Error("Score event lies outside its declared duration").throw;
        };
    };
    piece[\score].writeOSCFile(scratch +/+ "score.osc", 0, duration);
    File.use(scratch +/+ "duration.txt", "w", { |file| file.write(duration.asString) });
    "WEAVING_PIECE_SCORE_READY".postln;
    0.exit;
}.try { |error|
    error.reportError;
    1.exit;
};
)
