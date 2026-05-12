//! Consonant distance: voicing flip + manner-of-articulation rank +
//! 2D place-of-articulation embedding + lateral airflow penalty.
//!
//! Place is a Euclidean distance over an anatomical (x, y) embedding,
//! not the original 1-D column index. Labio-velar /w/ sits at the back
//! on x but at the lip end on y because it's articulated at both lips
//! and velum; the 1-D index put /w/ next to bilabial /m/ and far from
//! velar /k/, which is the opposite of the physics.
//!
//! Lateral airflow is an additive penalty so /l/ vs /ɹ/ — same place,
//! same voicing, both ranked "approximant" — comes out non-zero.

/// Place of articulation.
#[allow(missing_docs)]
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum Position {
    LabioVelar,
    BiLabial,
    LabioDental,
    LinguoLabial,
    Dental,
    Alveolar,
    PostAlveolar,
    RetroFlex,
    Palatal,
    Velar,
    Uvular,
    Pharyngeal,
    Glottal,
}

impl Position {
    /// Anatomical 2D coordinates, both in [0, 1].
    ///   x: front-of-mouth (0) → back-of-mouth (1)
    ///   y: lip-articulator (0) → tongue/throat-articulator (1)
    pub fn coords(self) -> (f64, f64) {
        match self {
            Self::LabioVelar   => (0.95, 0.05),
            Self::BiLabial     => (0.00, 0.05),
            Self::LabioDental  => (0.10, 0.30),
            Self::LinguoLabial => (0.05, 0.55),
            Self::Dental       => (0.20, 0.60),
            Self::Alveolar     => (0.30, 0.70),
            Self::PostAlveolar => (0.40, 0.75),
            Self::RetroFlex    => (0.50, 0.80),
            Self::Palatal      => (0.60, 0.85),
            Self::Velar        => (0.80, 0.90),
            Self::Uvular       => (0.90, 0.95),
            Self::Pharyngeal   => (0.95, 1.00),
            Self::Glottal      => (1.00, 1.00),
        }
    }
}

/// Manner of articulation.
#[allow(missing_docs)]
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum Manner {
    Nasal,
    Stop,
    SibilantFricative,
    NonSibilantFricative,
    LateralFricative,
    Approximant,
    TapFlap,
    Trill,
    LateralApproximant,
    LateralTapFlap,
}

impl Manner {
    /// Perceptual rank in [0, 1] along the sonority hierarchy.
    pub fn score(self) -> f64 {
        match self {
            Self::Stop                 => 0.00,
            Self::SibilantFricative    => 0.50,
            Self::NonSibilantFricative => 0.50,
            Self::LateralFricative     => 0.55,
            Self::Nasal                => 0.70,
            Self::TapFlap              => 0.85,
            Self::LateralTapFlap       => 0.85,
            Self::Trill                => 0.90,
            Self::LateralApproximant   => 1.00,
            Self::Approximant          => 1.00,
        }
    }

    /// True for manners that route airflow around the sides of the tongue.
    pub fn is_lateral(self) -> bool {
        matches!(
            self,
            Self::LateralFricative | Self::LateralApproximant | Self::LateralTapFlap
        )
    }
}

/// Features of a consonant in the inventory.
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct Consonant {
    /// Place of articulation.
    pub position: Position,
    /// Manner of articulation.
    pub manner: Manner,
    /// True if the vocal folds vibrate.
    pub voiced: bool,
}

/// Additive penalty when one consonant is voiced and the other isn't.
pub const VOICING_PENALTY: f64 = 0.15;
/// Maximum manner contribution to consonant distance.
pub const MANNER_SCALE: f64 = 0.45;
/// Maximum place contribution to consonant distance.
pub const PLACE_SCALE: f64 = 0.30;
/// Normaliser for the place Euclidean distance: max possible is sqrt(2).
pub const PLACE_NORM: f64 = std::f64::consts::SQRT_2;
/// Additive penalty when one consonant routes airflow laterally and the
/// other doesn't (e.g. /l/ vs /ɹ/).
pub const LATERAL_PENALTY: f64 = 0.10;

/// Every IPA consonant symbol the metric knows about, in canonical
/// (chart-traversal) order.
pub const INVENTORY: &[&str] = &[
    // Nasals
    "m̥","m","ɱ","n̼","n̥","n","ɳ̊","ɳ","ɲ̊","ɲ","ŋ̊","ŋ","ɴ",
    // Stops
    "p","b","p̪","b̪","t̼","d̼","t","d","ʈ","ɖ","c","ɟ","k","g","q","ɢ","ʡ","ʔ",
    // Sibilant fricatives
    "s","z","ʃ","ʒ","ʂ","ʐ","ɕ","ʑ",
    // Non-sibilant fricatives
    "ɸ","β","f","v","θ̼","ð̼","θ","ð","θ̠","ð̠","ɹ̠̊˔","ɹ̠˔","ɻ˔","ç","ʝ","x","ɣ","χ","ʁ","ħ","ʕ","h","ɦ",
    // Approximants
    "w","ʋ̥","ʋ","ɹ̥","ɹ","ɻ̊","ɻ","j̊","j","ɰ̊","ɰ","ʔ̞",
    // Taps/flaps
    "ⱱ̟","ⱱ","ɾ̼","ɾ̥","ɾ","ɽ̊","ɽ","ɢ̆","ʡ̆",
    // Trills
    "ʙ̥","ʙ","r̥","r","ʀ̥","ʀ","ʜ","ʢ",
    // Lateral fricatives
    "ɬ","ɮ","ɭ̊˔","ɭ˔","ʎ̝̊","ʎ̝","ʟ̝̊","ʟ̝",
    // Lateral approximants
    "l̥","l","ɭ̊","ɭ","ʎ̥","ʎ","ʟ̥","ʟ","ʟ̠",
    // Lateral taps/flaps
    "ɺ","ɭ̆","ʎ̆","ʟ̆",
];

/// Look up the feature data for an IPA consonant symbol.
///
/// The table is the full IPA pulmonic-consonant chart from
/// <https://en.wikipedia.org/wiki/International_Phonetic_Alphabet#Letters>,
/// transcribed once and embedded as a `match`.
#[allow(clippy::too_many_lines)]
pub fn lookup(symbol: &str) -> Option<Consonant> {
    use Manner::*;
    use Position::*;
    let c = |position, manner, voiced| Consonant { position, manner, voiced };
    Some(match symbol {
        // Nasals
        "m̥"  => c(BiLabial,     Nasal, false),
        "m"  => c(BiLabial,     Nasal, true),
        "ɱ"  => c(LabioDental,  Nasal, true),
        "n̼"  => c(LinguoLabial, Nasal, true),
        "n̥"  => c(Alveolar,     Nasal, false),
        "n"  => c(Alveolar,     Nasal, true),
        "ɳ̊"  => c(RetroFlex,    Nasal, false),
        "ɳ"  => c(RetroFlex,    Nasal, true),
        "ɲ̊"  => c(Palatal,      Nasal, false),
        "ɲ"  => c(Palatal,      Nasal, true),
        "ŋ̊"  => c(Velar,        Nasal, false),
        "ŋ"  => c(Velar,        Nasal, true),
        "ɴ"  => c(Uvular,       Nasal, true),
        // Stops
        "p"  => c(BiLabial,     Stop, false),
        "b"  => c(BiLabial,     Stop, true),
        "p̪"  => c(LabioDental,  Stop, false),
        "b̪"  => c(LabioDental,  Stop, true),
        "t̼"  => c(LinguoLabial, Stop, false),
        "d̼"  => c(LinguoLabial, Stop, true),
        "t"  => c(Alveolar,     Stop, false),
        "d"  => c(Alveolar,     Stop, true),
        "ʈ"  => c(RetroFlex,    Stop, false),
        "ɖ"  => c(RetroFlex,    Stop, true),
        "c"  => c(Palatal,      Stop, false),
        "ɟ"  => c(Palatal,      Stop, true),
        "k"  => c(Velar,        Stop, false),
        "g"  => c(Velar,        Stop, true),
        "q"  => c(Uvular,       Stop, false),
        "ɢ"  => c(Uvular,       Stop, true),
        "ʡ"  => c(Pharyngeal,   Stop, false),
        "ʔ"  => c(Glottal,      Stop, false),
        // Sibilant fricatives
        "s"  => c(Alveolar,     SibilantFricative, false),
        "z"  => c(Alveolar,     SibilantFricative, true),
        "ʃ"  => c(PostAlveolar, SibilantFricative, false),
        "ʒ"  => c(PostAlveolar, SibilantFricative, true),
        "ʂ"  => c(RetroFlex,    SibilantFricative, false),
        "ʐ"  => c(RetroFlex,    SibilantFricative, true),
        "ɕ"  => c(Palatal,      SibilantFricative, false),
        "ʑ"  => c(Palatal,      SibilantFricative, true),
        // Non-sibilant fricatives
        "ɸ"  => c(BiLabial,     NonSibilantFricative, false),
        "β"  => c(BiLabial,     NonSibilantFricative, true),
        "f"  => c(LabioDental,  NonSibilantFricative, false),
        "v"  => c(LabioDental,  NonSibilantFricative, true),
        "θ̼"  => c(LinguoLabial, NonSibilantFricative, false),
        "ð̼"  => c(LinguoLabial, NonSibilantFricative, true),
        "θ"  => c(Dental,       NonSibilantFricative, false),
        "ð"  => c(Dental,       NonSibilantFricative, true),
        "θ̠"  => c(Alveolar,     NonSibilantFricative, false),
        "ð̠"  => c(Alveolar,     NonSibilantFricative, true),
        "ɹ̠̊˔"  => c(PostAlveolar, NonSibilantFricative, false),
        "ɹ̠˔"  => c(PostAlveolar, NonSibilantFricative, true),
        "ɻ˔"  => c(RetroFlex,    NonSibilantFricative, true),
        "ç"  => c(Palatal,      NonSibilantFricative, false),
        "ʝ"  => c(Palatal,      NonSibilantFricative, true),
        "x"  => c(Velar,        NonSibilantFricative, false),
        "ɣ"  => c(Velar,        NonSibilantFricative, true),
        "χ"  => c(Uvular,       NonSibilantFricative, false),
        "ʁ"  => c(Uvular,       NonSibilantFricative, true),
        "ħ"  => c(Pharyngeal,   NonSibilantFricative, false),
        "ʕ"  => c(Pharyngeal,   NonSibilantFricative, true),
        "h"  => c(Glottal,      NonSibilantFricative, false),
        "ɦ"  => c(Glottal,      NonSibilantFricative, true),
        // Approximants
        "w"  => c(LabioVelar,   Approximant, true),
        "ʋ̥"  => c(LabioDental,  Approximant, false),
        "ʋ"  => c(LabioDental,  Approximant, true),
        "ɹ̥"  => c(Alveolar,     Approximant, false),
        "ɹ"  => c(Alveolar,     Approximant, true),
        "ɻ̊"  => c(RetroFlex,    Approximant, false),
        "ɻ"  => c(RetroFlex,    Approximant, true),
        "j̊"  => c(Palatal,      Approximant, false),
        "j"  => c(Palatal,      Approximant, true),
        "ɰ̊"  => c(Velar,        Approximant, false),
        "ɰ"  => c(Velar,        Approximant, true),
        "ʔ̞"  => c(Glottal,      Approximant, true),
        // Taps/flaps
        "ⱱ̟"  => c(BiLabial,     TapFlap, true),
        "ⱱ"  => c(LabioDental,  TapFlap, true),
        "ɾ̼"  => c(LinguoLabial, TapFlap, true),
        "ɾ̥"  => c(Alveolar,     TapFlap, false),
        "ɾ"  => c(Alveolar,     TapFlap, true),
        "ɽ̊"  => c(RetroFlex,    TapFlap, false),
        "ɽ"  => c(RetroFlex,    TapFlap, true),
        "ɢ̆"  => c(Uvular,       TapFlap, true),
        "ʡ̆"  => c(Pharyngeal,   TapFlap, true),
        // Trills
        "ʙ̥"  => c(BiLabial,     Trill, false),
        "ʙ"  => c(BiLabial,     Trill, true),
        "r̥"  => c(Alveolar,     Trill, false),
        "r"  => c(Alveolar,     Trill, true),
        "ʀ̥"  => c(Uvular,       Trill, false),
        "ʀ"  => c(Uvular,       Trill, true),
        "ʜ"  => c(Pharyngeal,   Trill, false),
        "ʢ"  => c(Pharyngeal,   Trill, true),
        // Lateral fricatives
        "ɬ"  => c(Alveolar,     LateralFricative, false),
        "ɮ"  => c(Alveolar,     LateralFricative, true),
        "ɭ̊˔" => c(RetroFlex,    LateralFricative, false),
        "ɭ˔" => c(RetroFlex,    LateralFricative, true),
        "ʎ̝̊"  => c(Palatal,      LateralFricative, false),
        "ʎ̝"  => c(Palatal,      LateralFricative, true),
        "ʟ̝̊"  => c(Velar,        LateralFricative, false),
        "ʟ̝"  => c(Velar,        LateralFricative, true),
        // Lateral approximants
        "l̥"  => c(Alveolar,     LateralApproximant, false),
        "l"  => c(Alveolar,     LateralApproximant, true),
        "ɭ̊"  => c(RetroFlex,    LateralApproximant, false),
        "ɭ"  => c(RetroFlex,    LateralApproximant, true),
        "ʎ̥"  => c(Palatal,      LateralApproximant, false),
        "ʎ"  => c(Palatal,      LateralApproximant, true),
        "ʟ̥"  => c(Velar,        LateralApproximant, false),
        "ʟ"  => c(Velar,        LateralApproximant, true),
        "ʟ̠"  => c(Uvular,       LateralApproximant, true),
        // Lateral taps/flaps
        "ɺ"  => c(Alveolar,     LateralTapFlap, true),
        "ɭ̆"  => c(RetroFlex,    LateralTapFlap, true),
        "ʎ̆"  => c(Palatal,      LateralTapFlap, true),
        "ʟ̆"  => c(Velar,        LateralTapFlap, true),
        _ => return None,
    })
}

/// Distance between two consonants, scaled into [0, 1].
///
/// Returns `None` if either symbol is unknown.
pub fn distance(p1: &str, p2: &str) -> Option<f64> {
    if p1 == p2 {
        return Some(0.0);
    }
    let c1 = lookup(p1)?;
    let c2 = lookup(p2)?;

    let mut penalty = 0.0;
    if c1.voiced != c2.voiced {
        penalty += VOICING_PENALTY;
    }
    penalty += MANNER_SCALE * (c1.manner.score() - c2.manner.score()).abs();
    if c1.manner.is_lateral() != c2.manner.is_lateral() {
        penalty += LATERAL_PENALTY;
    }
    let (x1, y1) = c1.position.coords();
    let (x2, y2) = c2.position.coords();
    penalty += PLACE_SCALE * ((x1 - x2).powi(2) + (y1 - y2).powi(2)).sqrt() / PLACE_NORM;

    Some(penalty.min(1.0))
}

#[cfg(test)]
mod tests {
    use super::*;

    const EPS: f64 = 1e-12;

    #[test]
    fn matches_ruby_consonant_distances() {
        // Reference values produced by the Ruby implementation.
        let cases: &[(&str, &str, f64)] = &[
            ("p", "b", 0.15),
            ("p", "t", 0.151_863_425_484_874_36),
            ("p", "k", 0.247_613_610_288_287_66),
            ("m", "n", 0.151_863_425_484_874_36),
            ("s", "z", 0.15),
            ("s", "ʃ", 0.023_717_082_451_262_854),
            ("s", "t", 0.225),
            ("n", "l", 0.235_000_000_000_000_04),
            ("ŋ", "g", 0.315),
            ("l", "ɹ", 0.1),
            ("h", "k", 0.272_434_164_902_525_7),
            ("θ", "t", 0.255),
            ("ð", "d", 0.255),
            ("w", "j", 0.185_236_335_528_427),
            ("ɮ", "z", 0.122_500_000_000_000_03),
        ];

        for (a, b, expected) in cases {
            let got = distance(a, b).expect("inventory pair");
            assert!(
                (got - expected).abs() < EPS,
                "distance({a:?}, {b:?}) = {got}, expected {expected}",
            );
        }
    }

    #[test]
    fn identity_is_zero() {
        // A representative subset; the full inventory is large.
        for s in ["p", "b", "t", "k", "m", "n", "s", "ʃ", "l", "ɹ", "ŋ", "ɮ"] {
            assert_eq!(distance(s, s), Some(0.0));
        }
    }

    #[test]
    fn l_and_r_are_not_tied_at_zero() {
        // Without LATERAL_PENALTY, /l/ and /ɹ/ would both be alveolar
        // approximants with manner rank 1.0 and voicing match — distance 0.
        let d = distance("l", "ɹ").unwrap();
        assert!(d > 0.0, "/l/-/ɹ/ should be > 0, got {d}");
    }

    #[test]
    fn unknown_symbol_returns_none() {
        assert!(distance("Z", "p").is_none());
    }
}
