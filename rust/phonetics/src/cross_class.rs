//! Cross-class bridge: consonant ↔ vowel distance.
//!
//! English perception treats /j/, /w/, /ɹ/, /ɰ/ as non-syllabic versions
//! of /i/, /u/, /ɝ/, /ɯ/ respectively — Mad Gab's "yes" ≈ "Es" depends
//! on this bridge. Glottals are mostly an air pulse, also nearer to
//! vowels than to a true stop or fricative. Everything else uses
//! [`CROSS_CLASS_DEFAULT`](crate::symbols::CROSS_CLASS_DEFAULT).

use crate::symbols::{CROSS_CLASS_DEFAULT, CROSS_CLASS_NEAR_BRIDGE};

/// Returns the bridge cost when `consonant` is an approximant with
/// listed vowel-distance entries. Vowels not specifically listed under
/// a bridge consonant get `CROSS_CLASS_NEAR_BRIDGE`. Non-bridge
/// consonants return `None`.
fn approximant_bridge(consonant: &str, vowel: &str) -> Option<f64> {
    let cost = match (consonant, vowel) {
        ("j", "i") => 0.10,
        ("j", "ɪ") => 0.14,
        ("j", "y") => 0.18,
        ("j", "e") => 0.22,
        ("w", "u") => 0.10,
        ("w", "ʊ") => 0.14,
        ("w", "o") => 0.22,
        ("w", "ɔ") => 0.30,
        ("w", "ɯ") => 0.20,
        ("ɹ", "ɝ") => 0.08,
        ("ɹ", "ə") => 0.25,
        ("ɰ", "ɯ") => 0.10,
        ("ɰ", "u") => 0.20,
        // Bridge consonants without a specific vowel entry.
        ("j" | "w" | "ɹ" | "ɰ", _) => CROSS_CLASS_NEAR_BRIDGE,
        _ => return None,
    };
    Some(cost)
}

/// Glottal-bridge cost; glottals are nearly vowel-like everywhere.
fn glottal_bridge(consonant: &str) -> Option<f64> {
    Some(match consonant {
        "h" | "ɦ" => 0.50,
        "ʔ"       => 0.55,
        _ => return None,
    })
}

/// Look up the cross-class distance for a (consonant, vowel) pair.
/// Falls back to `CROSS_CLASS_DEFAULT` when neither bridge fires.
pub fn distance(consonant: &str, vowel: &str) -> f64 {
    if let Some(c) = approximant_bridge(consonant, vowel) {
        return c;
    }
    if let Some(c) = glottal_bridge(consonant) {
        return c;
    }
    CROSS_CLASS_DEFAULT
}
