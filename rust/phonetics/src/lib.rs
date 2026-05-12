//! Phonetics: IPA-based phonetic distance.
//!
//! Two-tier API, same as the Ruby reference implementation:
//!
//! * [`distance`] — strict per-phoneme acoustic distance, fed to
//!   [`levenshtein`] for whole-string edit distance. The right call for
//!   accent clustering, dialect work, and ASR error analysis.
//!
//! * [`Confusion::distance`](confusion::Confusion::distance) — listener-
//!   confusion distance, calibrated against Mad Gab puzzle data. Uses
//!   Gotoh's affine-gap DP plus a weak-phoneme indel discount and an
//!   empirical-confusion overlay. The right call for Mad Gab solving,
//!   pun detection, and mishearing modelling.
//!
//! Both tiers share the same per-phoneme cost basis. Improvements to the
//! acoustic model propagate to both metrics automatically.
//!
//! ```
//! use phonetics::distance;
//! // Tense /i/ versus lax /ɪ/ — close in Bark space.
//! assert!((distance("i", "ɪ") - 0.060_056).abs() < 1e-3);
//! // The same vowel twice is exactly zero.
//! assert_eq!(distance("ə", "ə"), 0.0);
//! ```

#![doc(html_root_url = "https://docs.rs/phonetics/0.1.0")]

pub mod compounds;
pub mod consonants;
pub mod cross_class;
pub mod diacritics;
pub mod symbols;
pub mod vowels;

mod distance;

pub use distance::distance;
