// Minimal executable metadata contract for curated pieces.
(
~weavingPiece = { |values|
    var required = #[name, description, engines, tags, mode, duration, status];
    required.do { |key|
        if(values[key].isNil) {
            Error("piece metadata is missing: %".format(key)).throw;
        };
    };
    if(#[active, study, archived].includes(values[\status]).not) {
        Error("piece status must be active, study, or archived").throw;
    };
    values
};
)
