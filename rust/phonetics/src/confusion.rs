//! Listener-confusion distance — Gotoh affine-gap DP over IPA tokens,
//! with weak-phoneme indel discount, boundary-token discount, and an
//! empirical-confusion overlay on top of the acoustic substitution
//! cost.
//!
//! Where [`crate::levenshtein`] answers "how different are these two
//! waveforms?", this answers "will a listener parse one as the other?".
//! Calibrated against Mad Gab puzzle data and against the maintainer's
//! West Coast American English. The overlay is a hand-curated table;
//! the DP shape is from Gotoh (1982).
//!
//! Three matrices:
//!
//!   M[i][j]   best score ending in a match/substitution
//!   X[i][j]   best score ending in an a-consuming gap
//!   Y[i][j]   best score ending in a b-consuming gap
//!
//! Affine gap pricing: opening a gap costs `GAP_OPEN`, extending one
//! already open costs `GAP_EXTEND` << `GAP_OPEN`. Mad Gab clues
//! typically add filler phonemes at word boundaries; one long gap
//! costs `GAP_OPEN + (k-1) * GAP_EXTEND`, not `k * GAP_OPEN`.

use crate::{distance as phoneme_distance, symbols, tokenizer};

// ------------------------------------------------------------------
// Tuning constants
// ------------------------------------------------------------------

/// Cost of starting a new gap.
pub const GAP_OPEN: f64 = 0.60;

/// Cost of extending an already-open gap by one phoneme.
pub const GAP_EXTEND: f64 = 0.25;

/// Indel cost for "weak" phonemes — those routinely inserted, dropped,
/// or hallucinated in casual English: /ə/, /h/, /ʔ/, /ɦ/.
pub const WEAK_INDEL_COST: f64 = 0.15;

/// Indel cost for the word-boundary token. Lower than WEAK_INDEL_COST
/// because re-syllabification is the operation Mad Gab encodes; we
/// don't want to punish it.
pub const BOUNDARY_INDEL_COST: f64 = 0.02;

/// The four "weak" phonemes — segments with the highest measured
/// deletion/insertion rates in conversational English.
pub const WEAK_PHONEMES: &[&str] = &["ə", "h", "ʔ", "ɦ"];

/// True if `phoneme` is in the weak tier OR is the boundary token.
pub fn weak(phoneme: &str) -> bool {
    phoneme == symbols::BOUNDARY_TOKEN || WEAK_PHONEMES.contains(&phoneme)
}

/// Tier-appropriate indel cost for `phoneme`, or `None` if it should
/// fall back to the affine GAP_OPEN/GAP_EXTEND machinery.
pub fn weak_indel_cost(phoneme: &str) -> Option<f64> {
    if phoneme == symbols::BOUNDARY_TOKEN {
        Some(BOUNDARY_INDEL_COST)
    } else if WEAK_PHONEMES.contains(&phoneme) {
        Some(WEAK_INDEL_COST)
    } else {
        None
    }
}

// ------------------------------------------------------------------
// Empirical-confusion overlay
// ------------------------------------------------------------------
//
// Pairs whose acoustic distance under `crate::distance` overstates the
// perceptual gap. The table mixes cross-variety findings (Miller-Nicely
// 1955, generic English speech-perception studies) with American-
// English-specific mergers — most of the overlay is calibrated against
// a West Coast American baseline because that's the dialect the
// maintainer hears natively.

/// (sym_a, sym_b, perceptual_cost). The lookup treats pairs as
/// unordered: sub_cost(a, b) == sub_cost(b, a).
const OVERLAY: &[(&str, &str, f64)] = &[
    // Cross-variety
    ("θ", "t", 0.18),
    ("ð", "d", 0.18),
    ("θ", "s", 0.12),
    ("ð", "z", 0.12),
    ("p", "f", 0.20),
    ("b", "v", 0.20),
    ("t", "s", 0.20),
    ("d", "z", 0.20),
    ("l", "ɹ", 0.15),
    // American (esp. WCE)
    ("t", "ɾ", 0.10),
    ("d", "ɾ", 0.05),
    ("ɑ", "ɔ", 0.05),
    ("ɑ", "ɒ", 0.05),
    ("t", "ʔ", 0.08),
    ("d", "ʔ", 0.20),
    ("u", "y", 0.15),
    ("u", "ɯ", 0.15),
    ("u", "ʉ", 0.10),
    ("o", "ə", 0.20),
    ("ʌ", "ɑ", 0.10),
];

/// Returns the overlay cost for an unordered pair, if present.
fn overlay_cost(a: &str, b: &str) -> Option<f64> {
    for &(x, y, cost) in OVERLAY {
        if (x == a && y == b) || (x == b && y == a) {
            return Some(cost);
        }
    }
    None
}

/// Per-phoneme substitution cost used by the Confusion DP. Identity
/// short-circuits; then the overlay; then the acoustic metric.
pub fn sub_cost(a: &str, b: &str) -> f64 {
    if a == b {
        return 0.0;
    }
    if let Some(c) = overlay_cost(a, b) {
        return c;
    }
    phoneme_distance(a, b)
}

// ------------------------------------------------------------------
// Gotoh DP
// ------------------------------------------------------------------

/// Listener-confusion distance between two IPA strings.
pub fn distance(s1: &str, s2: &str) -> f64 {
    let a = tokenizer::tokens(s1, true);
    let b = tokenizer::tokens(s2, true);
    distance_from_tokens(&a, &b)
}

/// 0..1 normalised similarity score. Worst case is one substitution
/// per position in the longer string; dividing by max(len) gives a
/// bounded judgement comparable across phrase lengths.
pub fn similarity(s1: &str, s2: &str) -> f64 {
    let a = tokenizer::tokens(s1, true);
    let b = tokenizer::tokens(s2, true);
    let max_n = a.len().max(b.len());
    if max_n == 0 {
        return 1.0;
    }
    let d = distance_from_tokens(&a, &b);
    (1.0 - d / max_n as f64).max(0.0)
}

/// Confusion distance over pre-tokenised phoneme sequences.
#[allow(clippy::too_many_lines)]
pub fn distance_from_tokens<S: AsRef<str>>(a: &[S], b: &[S]) -> f64 {
    let m = a.len();
    let n = b.len();
    if m == 0 && n == 0 {
        return 0.0;
    }
    if m == 0 {
        return seed_cost(b);
    }
    if n == 0 {
        return seed_cost(a);
    }

    let width = n + 1;
    let cells = (m + 1) * width;
    let inf = INF;
    let mut mm = vec![inf; cells];
    let mut xx = vec![inf; cells];
    let mut yy = vec![inf; cells];
    mm[0] = 0.0;

    // Seed gap-only edges.
    for i in 1..=m {
        let ph = a[i - 1].as_ref();
        let step = indel_step(ph, i == 1);
        let prev = if i == 1 { 0.0 } else { xx[(i - 1) * width] };
        xx[i * width] = prev + step;
    }
    for j in 1..=n {
        let ph = b[j - 1].as_ref();
        let step = indel_step(ph, j == 1);
        let prev = if j == 1 { 0.0 } else { yy[j - 1] };
        yy[j] = prev + step;
    }

    for i in 1..=m {
        let ai = a[i - 1].as_ref();
        let a_weak_cost = weak_indel_cost(ai);
        for j in 1..=n {
            let bj = b[j - 1].as_ref();
            let b_weak_cost = weak_indel_cost(bj);

            let here     = i * width + j;
            let up       = (i - 1) * width + j;
            let left     = i * width + (j - 1);
            let diag     = (i - 1) * width + (j - 1);

            // M: end in match/mismatch.
            mm[here] = min3(mm[diag], xx[diag], yy[diag]) + sub_cost(ai, bj);

            // X: end in an a-consuming gap.
            xx[here] = if let Some(c) = a_weak_cost {
                min3(mm[up], xx[up], yy[up]) + c
            } else {
                min3(mm[up] + GAP_OPEN, xx[up] + GAP_EXTEND, yy[up] + GAP_OPEN)
            };

            // Y: end in a b-consuming gap.
            yy[here] = if let Some(c) = b_weak_cost {
                min3(mm[left], xx[left], yy[left]) + c
            } else {
                min3(mm[left] + GAP_OPEN, yy[left] + GAP_EXTEND, xx[left] + GAP_OPEN)
            };
        }
    }

    let last = m * width + n;
    min3(mm[last], xx[last], yy[last])
}

// ------------------------------------------------------------------
// Helpers
// ------------------------------------------------------------------

const INF: f64 = 1e18;

#[inline]
fn min3(a: f64, b: f64, c: f64) -> f64 {
    a.min(b).min(c)
}

fn indel_step(phoneme: &str, opening: bool) -> f64 {
    if let Some(c) = weak_indel_cost(phoneme) {
        return c;
    }
    if opening { GAP_OPEN } else { GAP_EXTEND }
}

fn seed_cost<S: AsRef<str>>(tokens: &[S]) -> f64 {
    let mut total = 0.0;
    for (i, ph) in tokens.iter().enumerate() {
        total += indel_step(ph.as_ref(), i == 0);
    }
    total
}

#[cfg(test)]
mod tests {
    use super::*;

    const EPS: f64 = 1e-12;

    #[test]
    fn matches_ruby_reference_distances() {
        // Pure-Ruby reference values (f64).
        let cases: &[(&str, &str, f64)] = &[
            ("kæt", "kæt", 0.0),
            ("kæt", "kʌt", 0.145_085_455_502_268_37),
            ("ɪtsdʒʌstəstupɪdgeɪm",
             "hɪtsdʒʌstɪsduphɪdkeɪm",
             0.769_519_814_165_789_6),
            ("ɪtsdʒʌstəstupɪdgeɪm",
             "jɔrmʌðɝwɛrzsneɪkɝz",
             6.485_176_104_558_604),
            ("æpəlpaɪ", "eɪppʊlpaɪ", 1.047_133_181_946_413_6),
            ("nidəkɔfi", "nidɑkhɔffi", 0.968_204_431_378_303_3),
            ("aɪlʌvju", "aɪlʌvju", 0.0),
            ("ɪts dʒʌst", "ɪt sdʒʌst", 0.04),
            ("stupɪd", "stupɪdli", 0.85),
            ("stupɪd", "hstupɪd", 0.15),
            ("", "", 0.0),
            ("kæt", "", 1.1),
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
    fn empirical_overlay_fires_on_t_flapping() {
        // /t/-/ɾ/ acoustically ~0.5; overlay drops it to 0.10.
        assert!((sub_cost("t", "ɾ") - 0.10).abs() < EPS);
    }

    #[test]
    fn wce_overlay_fires_on_cot_caught() {
        assert!((sub_cost("ɑ", "ɔ") - 0.05).abs() < EPS);
    }

    #[test]
    fn similarity_is_one_for_identity() {
        assert_eq!(similarity("kæt", "kæt"), 1.0);
        assert_eq!(similarity("", ""), 1.0);
    }

    #[test]
    fn similarity_separates_madgab_pair_from_decoy() {
        let target = "ɪtsdʒʌstəstupɪdgeɪm";
        let clue   = "hɪtsdʒʌstɪsduphɪdkeɪm";
        let decoy  = "jɔrmʌðɝwɛrzsneɪkɝz";
        let s_clue  = similarity(target, clue);
        let s_decoy = similarity(target, decoy);
        assert!(s_clue - s_decoy >= 0.2,
                "clue {s_clue} not >= decoy {s_decoy} + 0.2");
    }

    #[test]
    fn boundary_indel_is_essentially_free() {
        // Same phonemes, repositioned word boundary. The pure-phoneme
        // contents are identical; confusion should reflect that.
        assert!(distance("ɪts dʒʌst", "ɪt sdʒʌst") < 0.05);
    }

    #[test]
    fn weak_phoneme_indel_is_cheap() {
        // Inserting /h/ at the head should cost roughly WEAK_INDEL_COST.
        assert!((distance("stupɪd", "hstupɪd") - WEAK_INDEL_COST).abs() < 0.01);
    }
}
