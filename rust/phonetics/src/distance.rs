//! Top-level distance dispatch.
//!
//! Routes vowel-vowel and consonant-consonant pairs to their respective
//! modules. Cross-class bridges (approximant↔vowel, glottal↔vowel),
//! compound phonemes, and diacritics land in subsequent commits.

use crate::{consonants, vowels};

/// Distance between two phonemes, scaled to [0, 1].
///
/// Identical symbols return 0.0. Vowel-vowel and consonant-consonant
/// pairs route to the corresponding feature-based metric. Anything else
/// currently returns 1.0 as a placeholder.
pub fn distance(p1: &str, p2: &str) -> f64 {
    if p1 == p2 {
        return 0.0;
    }
    if let Some(d) = vowels::distance(p1, p2) {
        return d;
    }
    if let Some(d) = consonants::distance(p1, p2) {
        return d;
    }
    1.0
}
