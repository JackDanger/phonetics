//! Strict phonetic edit distance.
//!
//! Damerau-Levenshtein DP with INDEL_COST = 1.0 (one inserted or
//! deleted phoneme costs exactly one indel, regardless of its
//! neighbours — the operation costs what the operation costs, not what
//! happens to sit next to it). Adjacent transpositions cost
//! TRANSPOSE_COST < 2 * INDEL_COST because in casual speech swapping
//! adjacent phonemes is a real and cheap thing speakers do.
//!
//! Substitution cost is the per-phoneme acoustic distance returned by
//! [`crate::distance`], so improvements to the acoustic model land here
//! automatically.

use crate::tokenizer;

/// Cost of inserting or deleting one phoneme.
pub const INDEL_COST: f64 = 1.0;

/// Cost of an adjacent-pair transposition (the Damerau extension).
pub const TRANSPOSE_COST: f64 = 0.8;

/// Edit distance between two IPA strings under the strict acoustic
/// metric. Non-IPA characters are tokenised out before the DP runs.
pub fn distance(a: &str, b: &str) -> f64 {
    let ta = tokenizer::tokens(a, false);
    let tb = tokenizer::tokens(b, false);
    distance_from_tokens(&ta, &tb)
}

/// Edit distance over pre-tokenised phoneme sequences.
pub fn distance_from_tokens<S: AsRef<str>>(a: &[S], b: &[S]) -> f64 {
    let m = a.len();
    let n = b.len();
    if m == 0 && n == 0 {
        return 0.0;
    }

    // d[i][j] flattened; width = n + 1.
    let width = n + 1;
    let mut d = vec![0.0_f64; (m + 1) * width];

    // Seed: matching the empty string against the first i phonemes of a
    // costs i indels; symmetric for b.
    for i in 0..=m {
        d[i * width] = i as f64 * INDEL_COST;
    }
    for j in 0..=n {
        d[j] = j as f64 * INDEL_COST;
    }

    for i in 1..=m {
        for j in 1..=n {
            let ai = a[i - 1].as_ref();
            let bj = b[j - 1].as_ref();
            let sub_cost = crate::distance(ai, bj);

            let delete = d[(i - 1) * width + j] + INDEL_COST;
            let insert = d[i * width + (j - 1)] + INDEL_COST;
            let substitute = d[(i - 1) * width + (j - 1)] + sub_cost;

            let mut best = delete.min(insert).min(substitute);

            // Damerau adjacent-transposition.
            if i > 1
                && j > 1
                && a[i - 1].as_ref() == b[j - 2].as_ref()
                && a[i - 2].as_ref() == b[j - 1].as_ref()
            {
                let transpose = d[(i - 2) * width + (j - 2)] + TRANSPOSE_COST;
                if transpose < best {
                    best = transpose;
                }
            }

            d[i * width + j] = best;
        }
    }

    d[m * width + n]
}

#[cfg(test)]
mod tests {
    use super::distance;

    const EPS: f64 = 1e-12;

    #[test]
    fn matches_ruby_reference_distances() {
        // Reference values produced by Ruby's Phonetics::RubyLevenshtein.
        let cases: &[(&str, &str, f64)] = &[
            ("kæt", "kæt", 0.0),
            ("dɪsug", "ɪsug", 1.0),
            ("izok", "ɪsug", 0.425_001_067_076_172_47),
            ("kæt", "", 3.0),
            ("kæt", "kæɪt", 1.0),
            ("kæt", "kʌt", 0.145_085_455_502_268_37),
            ("ɪtsdʒʌstəstupɪdgeɪm",
             "hɪtsdʒʌstɪsduphɪdkeɪm",
             2.469_519_814_165_789_5),
            ("mɔop", "sinkœ", 3.025_788_981_175_774),
            ("bæd", "ben", 0.510_984_626_268_258_8),
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
    fn empty_pair_is_zero() {
        assert_eq!(distance("", ""), 0.0);
    }

    #[test]
    fn one_indel_costs_INDEL_COST() {
        // Inserting or deleting one phoneme costs exactly the indel.
        assert!((distance("kæt", "kæte") - super::INDEL_COST).abs() < 1e-6);
    }

    #[test]
    fn identity_strings_are_zero() {
        for s in ["", "kæt", "stupɪdgeɪm", "ɪtsdʒʌstəstupɪdgeɪm"] {
            assert_eq!(distance(s, s), 0.0);
        }
    }

    #[test]
    fn symmetric() {
        let pairs = [
            ("kæt", "kʌt"),
            ("dɪsug", "ɪsug"),
            ("stupɪdgeɪm", "stupɪdli"),
        ];
        for (a, b) in pairs {
            let d_ab = distance(a, b);
            let d_ba = distance(b, a);
            assert!((d_ab - d_ba).abs() < EPS, "asymmetric: {a}/{b}");
        }
    }
}
