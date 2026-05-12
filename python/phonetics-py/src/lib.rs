//! PyO3 bindings around the `phonetics` core crate.
//!
//! Importable as the `phonetics._native` submodule of the wheel; the
//! pure-Python `phonetics/__init__.py` re-exports the bare functions
//! at the package root for `from phonetics import confusion` etc.
//!
//! All real work lives in the core crate. This file is the
//! impedance-matching layer between Rust types and Python's ABI.

use pyo3::prelude::*;

#[pymodule]
fn _native(m: &Bound<'_, PyModule>) -> PyResult<()> {
    m.add_function(wrap_pyfunction!(distance, m)?)?;
    m.add_function(wrap_pyfunction!(confusion, m)?)?;
    m.add_function(wrap_pyfunction!(levenshtein, m)?)?;
    m.add_function(wrap_pyfunction!(similarity, m)?)?;
    m.add_function(wrap_pyfunction!(sub_cost, m)?)?;
    m.add_function(wrap_pyfunction!(tokenize, m)?)?;
    Ok(())
}

/// Acoustic distance between two phoneme symbols.
#[pyfunction]
fn distance(a: &str, b: &str) -> f64 {
    phonetics::distance(a, b)
}

/// Listener-confusion distance between two IPA strings.
#[pyfunction]
fn confusion(a: &str, b: &str) -> f64 {
    phonetics::confusion(a, b)
}

/// Strict phonetic edit distance between two IPA strings.
#[pyfunction]
fn levenshtein(a: &str, b: &str) -> f64 {
    phonetics::levenshtein(a, b)
}

/// 0..1 normalised similarity, derived from the Confusion distance.
#[pyfunction]
fn similarity(a: &str, b: &str) -> f64 {
    phonetics::similarity(a, b)
}

/// Perceptual per-phoneme substitution cost (acoustic + empirical
/// confusion overlay).
#[pyfunction]
fn sub_cost(a: &str, b: &str) -> f64 {
    phonetics::confusion::sub_cost(a, b)
}

/// Split an IPA string into a list of phoneme tokens.
#[pyfunction]
#[pyo3(signature = (input, boundaries = false))]
fn tokenize(input: &str, boundaries: bool) -> Vec<String> {
    phonetics::tokens(input, boundaries)
}
