//! Suprasegmental and modifier diacritics.
//!
//! Each diacritic character either attaches to the preceding base
//! phoneme (length, aspiration, palatalization, etc.) or to the
//! following base phoneme (stress marks, which in IPA precede the
//! stressed syllable). The tokenizer absorbs them into the same token;
//! the distance metric splits them back out via [`decompose`] and
//! charges a small additive cost when modifier sets differ.

/// Kinds of suprasegmental modifier recognised by the metric.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum Diacritic {
    /// `ː` — full length.
    Long,
    /// `ˑ` — half-length.
    HalfLong,
    /// `ʰ` — aspiration.
    Aspirated,
    /// `ʲ` — palatalization.
    Palatalized,
    /// `ˤ` — pharyngealization.
    Pharyngealized,
    /// `ˠ` — velarization.
    Velarized,
    /// Combining tilde above (U+0303) — nasalization.
    Nasalized,
    /// `ˈ` — primary stress.
    PrimaryStress,
    /// `ˌ` — secondary stress.
    SecondaryStress,
}

impl Diacritic {
    /// Additive cost when this modifier is present on one phoneme but
    /// not the other.
    pub fn penalty(self) -> f64 {
        match self {
            Self::Long             => 0.05,
            Self::HalfLong         => 0.025,
            Self::Aspirated        => 0.04,
            Self::Palatalized      => 0.06,
            Self::Pharyngealized   => 0.07,
            Self::Velarized        => 0.07,
            Self::Nasalized        => 0.06,
            Self::PrimaryStress    => 0.05,
            Self::SecondaryStress  => 0.03,
        }
    }

    /// Classify a single Unicode character as a diacritic. The combining
    /// tilde is a multi-byte sequence in UTF-8 but one Unicode scalar.
    pub fn from_char(c: char) -> Option<Self> {
        Some(match c {
            'ː' => Self::Long,
            'ˑ' => Self::HalfLong,
            'ʰ' => Self::Aspirated,
            'ʲ' => Self::Palatalized,
            'ˤ' => Self::Pharyngealized,
            'ˠ' => Self::Velarized,
            '\u{0303}' => Self::Nasalized,
            'ˈ' => Self::PrimaryStress,
            'ˌ' => Self::SecondaryStress,
            _ => return None,
        })
    }

    /// True if this diacritic attaches to the *following* segment
    /// (stress marks); false for the preceding-attached ones.
    pub fn is_leading(self) -> bool {
        matches!(self, Self::PrimaryStress | Self::SecondaryStress)
    }
}

/// Generic fallback diacritic cost when an unrecognised diacritic-like
/// character ends up in a modifier set somehow.
pub const DEFAULT_PENALTY: f64 = 0.03;

/// Split a phoneme token into its base symbol and the set of diacritic
/// kinds it carries. Unrecognised characters stay in the base so a
/// misspelt input doesn't silently lose information.
pub fn decompose(token: &str) -> (String, Vec<Diacritic>) {
    let mut base = String::new();
    let mut mods: Vec<Diacritic> = Vec::new();
    for c in token.chars() {
        if let Some(d) = Diacritic::from_char(c) {
            if !mods.contains(&d) {
                mods.push(d);
            }
        } else {
            base.push(c);
        }
    }
    (base, mods)
}

/// Symmetric-difference cost between two diacritic sets.
pub fn distance(mods1: &[Diacritic], mods2: &[Diacritic]) -> f64 {
    if mods1.is_empty() && mods2.is_empty() {
        return 0.0;
    }
    let mut total = 0.0;
    for d in mods1 {
        if !mods2.contains(d) {
            total += d.penalty();
        }
    }
    for d in mods2 {
        if !mods1.contains(d) {
            total += d.penalty();
        }
    }
    total
}
