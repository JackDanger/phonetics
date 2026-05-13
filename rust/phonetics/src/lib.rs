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
//!
//! # Optional features
//!
//! * `transcriptions` — adds [`transcriptions::Corpus`] and
//!   [`transcriptions::Trie`] for looking words up by English spelling
//!   (`corpus.preferred_ipa("cat")`) or by IPA prefix
//!   (`trie.words_starting_at(chars, pos)`). The reverse direction has
//!   both an exact form and an approximate one
//!   ([`transcriptions::Trie::words_approximately_starting_at`])
//!   that allows per-character phonetic substitution within a
//!   caller-supplied cost budget. Used by
//!   <https://github.com/JackDanger/madgab>.
//!
//!   Off by default because callers that only need the distance math
//!   shouldn't pay for a JSON parser they won't use. Enable with:
//!
//!   ```toml
//!   phonetics-rs = { version = "0.3", features = ["transcriptions"] }
//!   ```

#![doc(html_root_url = "https://docs.rs/phonetics-rs/0.3.0")]

pub mod compounds;
pub mod confusion;
pub mod consonants;
pub mod cross_class;
pub mod diacritics;
pub mod levenshtein;
pub mod symbols;
pub mod tokenizer;
pub mod vowels;

#[cfg(feature = "transcriptions")]
pub mod transcriptions;

mod distance;

pub use confusion::distance as confusion;
pub use confusion::similarity;
pub use distance::distance;
pub use levenshtein::distance as levenshtein;
pub use tokenizer::tokens;
