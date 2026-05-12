//! Vowel distance in Bark-Euclidean space.
//!
//! F1 and F2 are stored in Hz but compared in Bark via the Traunmüller
//! (1990) approximation, because pitch perception is logarithmic and a
//! 200 Hz shift at F1=300 is enormous while the same shift at F2=2200
//! is barely audible. Roundedness and rhoticity are additive penalties
//! on top of the formant distance.

use std::sync::LazyLock;

/// Acoustic properties of one vowel in the inventory.
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct Vowel {
    /// First formant frequency in Hz.
    pub f1: f64,
    /// Second formant frequency in Hz.
    pub f2: f64,
    /// Lip rounding.
    pub rounded: bool,
    /// Rhoticity (for /ɝ/).
    pub rhotic: bool,
}

/// Tunable: vowels share a perceptually narrower space than consonants,
/// so the formant contribution is capped well below 1.0.
pub const VOWEL_SCALE: f64 = 0.60;

/// Additive penalty when one vowel is rounded and the other isn't.
pub const ROUNDING_PENALTY: f64 = 0.05;

/// Additive penalty for rhoticity mismatch.
pub const RHOTICITY_PENALTY: f64 = 0.20;

/// Hz → Bark. Traunmüller (1990) approximation.
pub fn bark(hz: f64) -> f64 {
    if hz <= 0.0 {
        return 0.0;
    }
    13.0 * (0.000_76 * hz).atan() + 3.5 * (hz / 7500.0).powi(2).atan()
}

/// IPA symbols in this inventory, in canonical order.
pub const INVENTORY: &[&str] = &[
    "i", "y", "ɪ", "e", "ø", "ɛ", "œ", "a", "ɶ", "ɑ", "ɒ",
    "ʌ", "ə", "ɝ", "ɔ", "ɤ", "o", "ɯ", "æ", "u", "ʊ",
];

/// Look up the formant data for an IPA vowel symbol.
///
/// Values from the cardinal-vowel measurements on Wikipedia (Daniel
/// Jones tradition), with the typo on /y/'s rounding flag corrected
/// from the original Ruby table and /ə/ no longer duplicating /ʌ/.
pub fn lookup(symbol: &str) -> Option<Vowel> {
    let v = |f1, f2, rounded, rhotic| Vowel { f1, f2, rounded, rhotic };
    Some(match symbol {
        "i" => v(240.0, 2400.0, false, false),
        "y" => v(235.0, 2100.0, true,  false),
        "ɪ" => v(300.0, 2100.0, false, false),
        "e" => v(390.0, 2300.0, false, false),
        "ø" => v(370.0, 1900.0, true,  false),
        "ɛ" => v(610.0, 1900.0, false, false),
        "œ" => v(585.0, 1710.0, true,  false),
        "a" => v(850.0, 1610.0, false, false),
        "ɶ" => v(820.0, 1530.0, true,  false),
        "ɑ" => v(750.0, 940.0,  false, false),
        "ɒ" => v(700.0, 760.0,  true,  false),
        "ʌ" => v(600.0, 1170.0, false, false),
        "ə" => v(500.0, 1500.0, false, false),
        "ɝ" => v(500.0, 1350.0, false, true),
        "ɔ" => v(500.0, 700.0,  true,  false),
        "ɤ" => v(460.0, 1310.0, false, false),
        "o" => v(360.0, 640.0,  true,  false),
        "ɯ" => v(300.0, 1390.0, false, false),
        "æ" => v(690.0, 1660.0, false, false),
        "u" => v(250.0, 595.0,  true,  false),
        "ʊ" => v(380.0, 950.0,  true,  false),
        _ => return None,
    })
}

/// Largest Bark-Euclidean distance achievable within the inventory.
/// Memoised; computed once on first access.
static BARK_SPAN: LazyLock<f64> = LazyLock::new(|| {
    let coords: Vec<(f64, f64)> = INVENTORY
        .iter()
        .map(|s| {
            let v = lookup(s).expect("INVENTORY entries must be in lookup()");
            (bark(v.f1), bark(v.f2))
        })
        .collect();
    let f1_min = coords.iter().map(|c| c.0).fold(f64::INFINITY, f64::min);
    let f1_max = coords.iter().map(|c| c.0).fold(f64::NEG_INFINITY, f64::max);
    let f2_min = coords.iter().map(|c| c.1).fold(f64::INFINITY, f64::min);
    let f2_max = coords.iter().map(|c| c.1).fold(f64::NEG_INFINITY, f64::max);
    ((f1_max - f1_min).powi(2) + (f2_max - f2_min).powi(2)).sqrt()
});

/// Returns the cached Bark-span normaliser.
pub fn bark_span() -> f64 {
    *BARK_SPAN
}

/// Distance between two vowels, scaled into [0, 1].
///
/// Returns `None` if either symbol is not in the inventory.
pub fn distance(p1: &str, p2: &str) -> Option<f64> {
    if p1 == p2 {
        return Some(0.0);
    }
    let v1 = lookup(p1)?;
    let v2 = lookup(p2)?;
    let (a1, b1) = (bark(v1.f1), bark(v1.f2));
    let (a2, b2) = (bark(v2.f1), bark(v2.f2));
    let formant_dist = ((a1 - a2).powi(2) + (b1 - b2).powi(2)).sqrt() / bark_span();
    let mut penalty = formant_dist * VOWEL_SCALE;
    if v1.rounded != v2.rounded {
        penalty += ROUNDING_PENALTY;
    }
    if v1.rhotic != v2.rhotic {
        penalty += RHOTICITY_PENALTY;
    }
    Some(penalty.min(1.0))
}

#[cfg(test)]
mod tests {
    use super::*;

    /// Tolerance: the Ruby reference uses f64 throughout; we should match
    /// to at least 12 decimals.
    const EPS: f64 = 1e-12;

    /// Reference values produced by the Ruby implementation.
    /// Bumping a constant here means bumping it in lib/phonetics/distances.rb
    /// and confirming the parity tests still match.
    #[test]
    fn matches_ruby_vowel_distances() {
        let cases: &[(&str, &str, f64)] = &[
            ("i", "y", 0.099_760_210_846_103_59),
            ("i", "ɪ", 0.060_056_384_465_816_57),
            ("i", "u", 0.565_279_341_709_588),
            ("a", "ɑ", 0.214_576_497_544_325_4),
            ("æ", "ɛ", 0.064_974_568_637_334_88),
            ("ə", "ɝ", 0.241_916_659_928_285_43),
            ("o", "ə", 0.371_374_251_614_846_3),
            ("u", "y", 0.465_646_551_803_915_9),
            ("ʊ", "u", 0.172_060_682_790_273_34),
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
    fn bark_span_matches_ruby() {
        assert!((bark_span() - 10.148_711_232_912_262).abs() < EPS);
    }

    #[test]
    fn bark_for_known_frequencies() {
        // /i/'s F1 = 240 Hz → 2.349… Bark
        assert!((bark(240.0) - 2.349_000_345_620_559).abs() < EPS);
        // /a/'s F1 = 850 Hz → 7.501… Bark
        assert!((bark(850.0) - 7.501_208_750_766_951).abs() < EPS);
        // Edge: 0 Hz returns 0.
        assert_eq!(bark(0.0), 0.0);
    }

    #[test]
    fn identity_is_zero() {
        for s in INVENTORY {
            assert_eq!(distance(s, s), Some(0.0));
        }
    }

    #[test]
    fn symmetric() {
        for a in INVENTORY {
            for b in INVENTORY {
                let d_ab = distance(a, b).unwrap();
                let d_ba = distance(b, a).unwrap();
                assert!((d_ab - d_ba).abs() < EPS, "asymmetric: {a}/{b}");
            }
        }
    }

    #[test]
    fn unknown_symbol_returns_none() {
        assert!(distance("Z", "i").is_none());
        assert!(distance("i", "Z").is_none());
    }
}
