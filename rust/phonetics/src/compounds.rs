//! Compound phonemes — diphthongs and affricates that are recognised
//! as single perceptual units even though their IPA notation is two
//! characters.
//!
//! Distance for a compound vs another phoneme is the average of the
//! pairwise component distances; the shorter side is padded by
//! repeating its last segment so /aɪ/ vs /a/ charges half a phoneme
//! distance rather than nothing.

/// Decompose a compound phoneme symbol into its components. Returns
/// `None` for non-compound phonemes.
pub fn components(symbol: &str) -> Option<&'static [&'static str]> {
    Some(match symbol {
        // English-style diphthongs (both /aɪ/-form and /ɑɪ/-form).
        "aɪ" => &["a", "ɪ"],
        "ɑɪ" => &["ɑ", "ɪ"],
        "aʊ" => &["a", "ʊ"],
        "ɑʊ" => &["ɑ", "ʊ"],
        "ɔɪ" => &["ɔ", "ɪ"],
        "eɪ" => &["e", "ɪ"],
        "oʊ" => &["o", "ʊ"],
        "əʊ" => &["ə", "ʊ"],
        "ɪə" => &["ɪ", "ə"],
        "ʊə" => &["ʊ", "ə"],
        "ɛə" => &["ɛ", "ə"],
        // English affricates only. /ts/, /dz/ etc. would mis-tokenise
        // English plurals (cats, kids) as single phonemes; left out.
        "tʃ" => &["t", "ʃ"],
        "dʒ" => &["d", "ʒ"],
        _ => return None,
    })
}
