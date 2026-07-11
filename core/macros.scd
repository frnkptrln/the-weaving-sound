// Shared 0..1 macro contract for all pieces.
(
~weavingMacroNames = #[brightness, density, motion, space, grit, tension];
~weavingMacros = { |values = ()|
    var defaults = (
        brightness: 0.5, density: 0.5, motion: 0.5,
        space: 0.5, grit: 0.0, tension: 0.0
    );
    ~weavingMacroNames.do { |name|
        defaults[name] = values[name].ifNil(defaults[name]).clip(0.0, 1.0);
    };
    defaults
};
)
