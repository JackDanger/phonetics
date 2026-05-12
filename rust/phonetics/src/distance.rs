//! Top-level distance dispatch.
//!
//! For now this only routes vowel-vowel pairs through [`crate::vowels`].
//! Consonants, cross-class bridges, compound phonemes, and diacritics
//! land in subsequent commits.

use crate::vowels;

/// Distance between two phonemes, scaled to [0, 1].
///
/// Identical symbols return 0.0. Vowel-vowel pairs go through the
/// Bark-space metric. Anything else currently returns 1.0 — that's a
/// placeholder, not the final value, and is the next module to land.
pub fn distance(p1: &str, p2: &str) -> f64 {
    if p1 == p2 {
        return 0.0;
    }
    if let Some(d) = vowels::distance(p1, p2) {
        return d;
    }
    1.0
}
