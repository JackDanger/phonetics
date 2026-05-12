//! IPA phoneme tokenizer.
//!
//! Walks an input string and emits a sequence of phoneme tokens. The
//! recognition is longest-prefix: multi-character atoms like /tʃ/,
//! /aɪ/, and /ɝ/ win over their single-character constituents.
//!
//! Diacritics absorb into the segment they modify — trailing
//! modifiers attach to the preceding base phoneme, stress marks
//! attach to the following one. Whitespace is skipped by default; in
//! boundary mode (used by the Confusion metric) each whitespace
//! character emits the `#` boundary token.

use std::collections::HashSet;
use std::sync::LazyLock;

use crate::{compounds, consonants, diacritics::Diacritic, symbols, vowels};

/// Set of every recognised phoneme symbol. Includes the boundary token
/// so longest-prefix matching can pick it up on raw `#` input.
pub static PHONEME_SET: LazyLock<HashSet<&'static str>> = LazyLock::new(|| {
    let mut s: HashSet<&'static str> = HashSet::new();
    for &p in vowels::INVENTORY {
        s.insert(p);
    }
    for &p in consonants::INVENTORY {
        s.insert(p);
    }
    for &p in compounds::INVENTORY {
        s.insert(p);
    }
    s.insert(symbols::BOUNDARY_TOKEN);
    s
});

/// Largest phoneme-symbol size in characters (not bytes). Used as the
/// upper bound for longest-prefix matching.
pub static MAX_PHONEME_CHARS: LazyLock<usize> = LazyLock::new(|| {
    PHONEME_SET
        .iter()
        .map(|s| s.chars().count())
        .max()
        .unwrap_or(1)
});

/// True if `s` is a recognised phoneme symbol.
pub fn is_phoneme(s: &str) -> bool {
    PHONEME_SET.contains(s)
}

/// Characters that represent a word boundary in raw IPA input.
const BOUNDARY_CHARS: &[char] = &[' ', '\t', '_', '|'];

/// Tokenise an IPA string into a sequence of phoneme tokens.
///
/// When `boundaries` is true, each whitespace / boundary character
/// in the input emits the `#` token; otherwise they're skipped.
pub fn tokens(input: &str, boundaries: bool) -> Vec<String> {
    let chars: Vec<char> = input.chars().collect();
    let max_phoneme_size = *MAX_PHONEME_CHARS;
    let mut out: Vec<String> = Vec::new();
    let mut pending_prefix = String::new();
    let mut idx = 0;

    while idx < chars.len() {
        let ch = chars[idx];

        if BOUNDARY_CHARS.contains(&ch) {
            if boundaries {
                out.push(symbols::BOUNDARY_TOKEN.to_string());
            }
            idx += 1;
            continue;
        }

        // Stress marks bind forward; carry them onto the next emitted token.
        if let Some(d) = Diacritic::from_char(ch) {
            if d.is_leading() {
                pending_prefix.push(ch);
                idx += 1;
                continue;
            }
        }

        // Try longest-prefix match against the recognized inventory.
        let mut matched: Option<String> = None;
        let max = max_phoneme_size.min(chars.len() - idx);
        for size in (1..=max).rev() {
            let candidate: String = chars[idx..idx + size].iter().collect();
            if is_phoneme(&candidate) {
                matched = Some(candidate);
                idx += size;
                break;
            }
        }

        if let Some(base) = matched {
            let mut token = std::mem::take(&mut pending_prefix);
            token.push_str(&base);

            // Absorb any trailing diacritics that modify this phoneme.
            while idx < chars.len() {
                let next = chars[idx];
                match Diacritic::from_char(next) {
                    Some(d) if !d.is_leading() => {
                        token.push(next);
                        idx += 1;
                    }
                    _ => break,
                }
            }
            out.push(token);
        } else {
            // No recognised phoneme starts here; skip one character.
            idx += 1;
        }
    }

    out
}

#[cfg(test)]
mod tests {
    use super::*;

    fn t(s: &str) -> Vec<String> {
        tokens(s, false)
    }
    fn tb(s: &str) -> Vec<String> {
        tokens(s, true)
    }

    #[test]
    fn matches_ruby_reference_tokenisations() {
        // Reference outputs produced by the Ruby implementation.
        let cases: &[(&str, &[&str], &[&str])] = &[
            ("kæt",        &["k","æ","t"],                                       &["k","æ","t"]),
            ("wətɛvɝ",     &["w","ə","t","ɛ","v","ɝ"],                           &["w","ə","t","ɛ","v","ɝ"]),
            ("kuɹzlɑɪt",   &["k","u","ɹ","z","l","ɑɪ","t"],                       &["k","u","ɹ","z","l","ɑɪ","t"]),
            ("dʒʌstɪs",    &["dʒ","ʌ","s","t","ɪ","s"],                            &["dʒ","ʌ","s","t","ɪ","s"]),
            ("tʃɝtʃ",      &["tʃ","ɝ","tʃ"],                                       &["tʃ","ɝ","tʃ"]),
            ("stupɪdgeɪm", &["s","t","u","p","ɪ","d","g","eɪ","m"],                 &["s","t","u","p","ɪ","d","g","eɪ","m"]),
            ("wə t 9 ɛvɝ", &["w","ə","t","ɛ","v","ɝ"],                              &["w","ə","#","t","#","#","ɛ","v","ɝ"]),
            ("pʰɪt",       &["pʰ","ɪ","t"],                                        &["pʰ","ɪ","t"]),
            ("kʰæt̃",       &["kʰ","æ","t̃"],                                        &["kʰ","æ","t̃"]),
            ("ˈstop",      &["ˈs","t","o","p"],                                    &["ˈs","t","o","p"]),
            ("ˌɪntɝˈnæʃənl", &["ˌɪ","n","t","ɝ","ˈn","æ","ʃ","ə","n","l"],            &["ˌɪ","n","t","ɝ","ˈn","æ","ʃ","ə","n","l"]),
            ("stuːpɪd",    &["s","t","uː","p","ɪ","d"],                            &["s","t","uː","p","ɪ","d"]),
            ("aɪlʌvju",    &["aɪ","l","ʌ","v","j","u"],                            &["aɪ","l","ʌ","v","j","u"]),
        ];

        for (input, bare, with_bounds) in cases {
            let got_bare = t(input);
            let got_bnds = tb(input);
            let want_bare: Vec<String> = bare.iter().map(|s| s.to_string()).collect();
            let want_bnds: Vec<String> = with_bounds.iter().map(|s| s.to_string()).collect();
            assert_eq!(got_bare, want_bare, "bare tokenisation diverged for {input:?}");
            assert_eq!(got_bnds, want_bnds, "boundary tokenisation diverged for {input:?}");
        }
    }

    #[test]
    fn skips_unknown_characters() {
        assert_eq!(t("k9æt"), vec!["k".to_string(), "æ".to_string(), "t".to_string()]);
    }

    #[test]
    fn empty_input_yields_empty_output() {
        assert!(t("").is_empty());
        assert!(tb("").is_empty());
    }
}
