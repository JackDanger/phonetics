//! Magnus bindings around the `phonetics` core crate.
//!
//! Loaded into Ruby as `phonetics_ruby.bundle` / `.so`. The
//! gem-installed library calls `require 'phonetics/phonetics_ruby'`
//! and gets a populated `Phonetics` module with module functions
//! matching what the previous hand-written C extension exposed:
//!
//!   Phonetics.distance(a, b)              acoustic per-phoneme
//!   Phonetics.confusion(a, b)             listener-confusion distance
//!   Phonetics.levenshtein(a, b)           strict edit distance
//!   Phonetics.similarity(a, b)            normalised 0..1
//!   Phonetics.sub_cost(a, b)              perceptual per-phoneme
//!   Phonetics.tokenize(input, boundaries) phoneme stream
//!
//! All real work lives in the `phonetics` core crate. This file is
//! the impedance-matching layer between Rust types and Ruby's ABI.

use magnus::{function, Error, Ruby};

#[magnus::init]
fn init(ruby: &Ruby) -> Result<(), Error> {
    let phonetics = ruby.define_module("Phonetics")?;

    phonetics.define_module_function("distance",    function!(distance, 2))?;
    phonetics.define_module_function("confusion",   function!(confusion, 2))?;
    phonetics.define_module_function("levenshtein", function!(levenshtein, 2))?;
    phonetics.define_module_function("similarity",  function!(similarity, 2))?;
    phonetics.define_module_function("sub_cost",    function!(sub_cost, 2))?;
    phonetics.define_module_function("_tokenize",   function!(tokenize, 2))?;

    Ok(())
}

fn distance(a: String, b: String) -> f64 {
    phonetics::distance(&a, &b)
}

fn confusion(a: String, b: String) -> f64 {
    phonetics::confusion(&a, &b)
}

fn levenshtein(a: String, b: String) -> f64 {
    phonetics::levenshtein(&a, &b)
}

fn similarity(a: String, b: String) -> f64 {
    phonetics::similarity(&a, &b)
}

fn sub_cost(a: String, b: String) -> f64 {
    phonetics::confusion::sub_cost(&a, &b)
}

fn tokenize(input: String, boundaries: bool) -> Vec<String> {
    phonetics::tokens(&input, boundaries)
}
