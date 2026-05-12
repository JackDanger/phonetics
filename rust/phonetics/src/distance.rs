//! Top-level distance dispatch.
//!
//! `distance(p1, p2)` returns the acoustic distance between two phoneme
//! tokens, scaled to [0, 1]. The dispatch order matters:
//!
//!   1. Identity → 0.
//!   2. Boundary token (`#`) → 0 vs boundary, else `BOUNDARY_VS_PHONEME`.
//!   3. Diacritic decomposition: split the token into base + modifier
//!      set; recurse on the base; add a per-modifier mismatch cost.
//!   4. Compound expansion: if either side is a diphthong or affricate,
//!      compare component-by-component (padded by repeating the last
//!      segment), averaging.
//!   5. Class-based dispatch: vowel-vowel, consonant-consonant, or
//!      cross-class bridge.

use crate::{compounds, consonants, cross_class, diacritics, symbols, vowels};

/// Distance between two phoneme tokens, scaled to [0, 1].
pub fn distance(p1: &str, p2: &str) -> f64 {
    if p1 == p2 {
        return 0.0;
    }

    if p1 == symbols::BOUNDARY_TOKEN || p2 == symbols::BOUNDARY_TOKEN {
        return symbols::BOUNDARY_VS_PHONEME;
    }

    let (base1, mods1) = diacritics::decompose(p1);
    let (base2, mods2) = diacritics::decompose(p2);

    // If either side carried any diacritics, strip them and recompute
    // on the bases, then add a per-modifier mismatch cost.
    if !mods1.is_empty() || !mods2.is_empty() {
        let base_dist = base_pair_distance(&base1, &base2);
        return (base_dist + diacritics::distance(&mods1, &mods2)).min(1.0);
    }

    base_pair_distance(p1, p2)
}

/// Distance between two bare base phonemes (no diacritics on either
/// side). Handles compounds, class dispatch, and cross-class bridges.
fn base_pair_distance(p1: &str, p2: &str) -> f64 {
    if p1 == p2 {
        return 0.0;
    }

    let comp1 = compounds::components(p1);
    let comp2 = compounds::components(p2);
    if comp1.is_some() || comp2.is_some() {
        let a: Vec<&str> = comp1.map_or_else(|| vec![p1], <[&str]>::to_vec);
        let b: Vec<&str> = comp2.map_or_else(|| vec![p2], <[&str]>::to_vec);
        return compound_distance(&a, &b);
    }

    let is_vowel_1 = vowels::lookup(p1).is_some();
    let is_vowel_2 = vowels::lookup(p2).is_some();
    let is_cons_1  = consonants::lookup(p1).is_some();
    let is_cons_2  = consonants::lookup(p2).is_some();

    if is_vowel_1 && is_vowel_2 {
        return vowels::distance(p1, p2).unwrap_or(1.0);
    }
    if is_cons_1 && is_cons_2 {
        return consonants::distance(p1, p2).unwrap_or(1.0);
    }
    if is_cons_1 && is_vowel_2 {
        return cross_class::distance(p1, p2);
    }
    if is_vowel_1 && is_cons_2 {
        return cross_class::distance(p2, p1);
    }
    1.0
}

/// Pairwise component-mean distance for compound (or
/// compound-and-simple) phonemes. The shorter side is padded by
/// repeating its last segment so /aɪ/ vs /a/ charges half a phoneme
/// distance rather than nothing.
fn compound_distance(c1: &[&str], c2: &[&str]) -> f64 {
    let n = c1.len().max(c2.len());

    // Pad the shorter side by repeating its last entry.
    fn pad<'a>(v: &[&'a str], n: usize) -> Vec<&'a str> {
        let mut out: Vec<&'a str> = v.to_vec();
        if let Some(&last) = out.last() {
            while out.len() < n {
                out.push(last);
            }
        }
        out
    }
    let a = pad(c1, n);
    let b = pad(c2, n);

    let total: f64 = a
        .iter()
        .zip(b.iter())
        .map(|(x, y)| if x == y { 0.0 } else { distance(x, y) })
        .sum();
    total / n as f64
}

#[cfg(test)]
mod tests {
    use super::distance;

    const EPS: f64 = 1e-12;

    #[test]
    fn matches_ruby_dispatch_cases() {
        // Reference values produced by the Ruby implementation across
        // every dispatch branch: cross-class bridges, glottals, the
        // default cross-class, compound diphthongs and affricates,
        // compound-vs-simple averaging, diacritics, and the boundary
        // token.
        let cases: &[(&str, &str, f64)] = &[
            // Approximant↔vowel bridge
            ("j", "i", 0.10),
            ("j", "ɪ", 0.14),
            ("w", "u", 0.10),
            ("w", "o", 0.22),
            ("ɹ", "ɝ", 0.08),
            ("ɰ", "ɯ", 0.10),
            // Glottal bridge
            ("h", "a", 0.50),
            ("ʔ", "i", 0.55),
            ("ɦ", "ɛ", 0.50),
            // Default cross-class
            ("k", "i", 0.85),
            ("s", "u", 0.85),
            ("m", "a", 0.85),
            // Diphthongs
            ("aɪ", "ɑɪ", 0.107_288_248_772_162_7),
            ("aɪ", "eɪ", 0.130_229_442_812_957_87),
            ("aɪ", "a",  0.144_904_524_019_594_53),
            ("oʊ", "o",  0.067_465_504_570_433_46),
            // Affricates
            ("tʃ", "ʃ",  0.124_358_541_225_631_43),
            ("tʃ", "dʒ", 0.15),
            ("tʃ", "t",  0.124_358_541_225_631_43),
            ("dʒ", "ʒ",  0.124_358_541_225_631_43),
            // Compound vs unrelated → averages to the default
            ("aɪ", "k", 0.85),
            // Diacritics
            ("pʰ", "p",  0.04),
            ("uː", "u",  0.05),
            ("ˈp", "p",  0.05),
            ("pʰ", "bʰ", 0.15),
            // Boundary token
            ("#", "a", 0.95),
            ("#", "#", 0.0),
        ];

        for (a, b, expected) in cases {
            let got = distance(a, b);
            assert!(
                (got - expected).abs() < EPS,
                "distance({a:?}, {b:?}) = {got}, expected {expected}",
            );
        }
    }

    #[test]
    fn identity_is_zero_across_classes() {
        for s in ["i", "p", "aɪ", "tʃ", "pʰ", "#"] {
            assert_eq!(distance(s, s), 0.0);
        }
    }

    #[test]
    fn diphthong_against_its_nucleus_is_half_a_phoneme() {
        // /aɪ/ vs /a/ should be roughly distance(ɪ, a) / 2 since the
        // first component matches and only the second contributes.
        let direct = crate::vowels::distance("ɪ", "a").unwrap();
        let compound = distance("aɪ", "a");
        assert!(
            (compound - direct / 2.0).abs() < EPS,
            "compound={compound}, direct/2={}",
            direct / 2.0
        );
    }
}
