//! Shared phoneme symbol metadata.
//!
//! These constants are used by the distance dispatch and the tokenizer.

/// Synthetic phoneme token representing a word boundary. Used by the
/// Confusion metric to model re-syllabification cheaply.
pub const BOUNDARY_TOKEN: &str = "#";

/// Cost of substituting a word boundary against a real phoneme. Set high
/// enough that the Confusion algorithm prefers indeling the boundary
/// (via the cheap boundary-indel tier) over substituting it.
pub const BOUNDARY_VS_PHONEME: f64 = 0.95;

/// Default cross-class (consonant↔vowel) distance when no bridge applies.
/// Lower than 1.0 (the indel cost) on purpose: a consonant against a
/// vowel is more like a strong substitution than a categorical break.
pub const CROSS_CLASS_DEFAULT: f64 = 0.85;

/// Cross-class cost when the consonant is in the approximant bridge but
/// the specific vowel isn't enumerated.
pub const CROSS_CLASS_NEAR_BRIDGE: f64 = 0.55;
