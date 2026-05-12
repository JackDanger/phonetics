//! English → IPA word lookup, indexed by phoneme prefix for fast
//! "what words begin at this point in this IPA stream?" queries.
//!
//! The corpus format is the JSON shape produced by the Ruby gem's
//! `Phonetics::Transcriptions` (originally derived from CMU, Wiktionary,
//! and phonemicchart.com). Each entry looks like:
//!
//! ```json
//! "cat": {
//!   "rarity": 2201.5,
//!   "ipa": { "cmu": "kæt" },
//!   "alt_display": "CAT"
//! }
//! ```
//!
//! `rarity` is a frequency rank (lower = more common); `ipa` is a map
//! of source → transcription string; `alt_display` is a presentation
//! form (often the original spelling in some all-caps stylization).
//!
//! This module is feature-gated under `transcriptions` so the default
//! crate build stays minimal.

use std::collections::BTreeMap;
use std::collections::HashMap;

use serde::Deserialize;

/// Errors produced by transcription loading or lookup.
#[derive(Debug, thiserror::Error)]
#[allow(missing_docs)]
pub enum Error {
    #[error("could not parse transcription corpus as JSON: {0}")]
    Json(#[from] serde_json::Error),
}

/// Raw JSON entry shape. Used during corpus parsing; not in the public
/// API. `serde(default)` lets us tolerate corpora missing some fields.
#[derive(Debug, Deserialize)]
struct RawEntry {
    #[serde(default)]
    rarity: Option<f64>,
    #[serde(default)]
    ipa: HashMap<String, String>,
    #[serde(default)]
    alt_display: Option<String>,
}

/// A single pronunciation of a word from one of the corpus sources.
#[derive(Debug, Clone, PartialEq)]
pub struct Pronunciation {
    /// English headword as it appears in the corpus key.
    pub word: String,
    /// IPA transcription string for this pronunciation.
    pub ipa: String,
    /// Source label (e.g. `"cmu"`, `"wiktionary"`).
    pub source: String,
    /// Frequency rank; lower is more common. `None` if the corpus
    /// didn't supply one.
    pub rarity: Option<f64>,
    /// Display form (often upper-cased original spelling). `None` if
    /// the corpus didn't supply one.
    pub alt_display: Option<String>,
}

/// A trie of phoneme characters whose leaves carry the words that
/// pronounce that exact prefix.
///
/// The tree is built once at corpus load and queried with
/// [`Trie::words_starting_at`] during the Mad Gab search loop.
#[derive(Debug, Default)]
pub struct Trie {
    root: Node,
}

#[derive(Debug, Default)]
struct Node {
    /// BTreeMap rather than HashMap because the inventory is small per
    /// node (≤30 phoneme characters in practice) and BTree gives
    /// deterministic iteration without the hash cost.
    children: BTreeMap<char, Box<Node>>,
    /// Words whose IPA is exactly the path from root to here.
    terminations: Vec<Pronunciation>,
}

impl Trie {
    /// Parse a JSON corpus (the shape described in the module docs)
    /// and return a populated trie.
    ///
    /// A maximum rarity (= least common word to include) is accepted
    /// because the full corpus has long-tail entries that aren't
    /// useful for Mad Gab; cutting the tail dramatically shrinks the
    /// trie and speeds searches.
    ///
    /// If you also need word → IPA lookup, use [`Corpus::from_json`]
    /// which produces both directions in a single parse.
    pub fn from_json(json: &str, max_rarity: Option<f64>) -> Result<Self, Error> {
        Ok(Corpus::from_json(json, max_rarity)?.trie)
    }

    fn insert(&mut self, p: Pronunciation) {
        let mut node = &mut self.root;
        for ch in p.ipa.chars() {
            node = node.children.entry(ch).or_default();
        }
        node.terminations.push(p);
    }

    /// Iterate over every word whose IPA starts at `chars[offset..]`,
    /// yielding `(consumed_chars, pronunciation)` pairs.
    ///
    /// "Consumed chars" is the count of IPA characters this match
    /// covered — the caller uses it to advance through the stream.
    /// The same word may be yielded multiple times if multiple
    /// transcriptions are in the corpus for it.
    pub fn words_starting_at<'a>(
        &'a self,
        chars: &'a [char],
        offset: usize,
    ) -> impl Iterator<Item = (usize, &'a Pronunciation)> + 'a {
        TrieWalk {
            node: Some(&self.root),
            chars,
            offset,
            depth: 0,
            term_idx: 0,
            yielded_root_terminations: false,
        }
    }

    /// Total number of pronunciation entries in the trie.
    pub fn len(&self) -> usize {
        fn count(n: &Node) -> usize {
            n.terminations.len() + n.children.values().map(|c| count(c)).sum::<usize>()
        }
        count(&self.root)
    }

    /// True if the trie has no entries.
    pub fn is_empty(&self) -> bool {
        self.len() == 0
    }
}

/// Bidirectional lookup: forward (word → IPAs) and reverse (IPA
/// prefix → words). One parse builds both; share one corpus across
/// transcription and generator workloads.
#[derive(Debug, Default)]
pub struct Corpus {
    /// Reverse index — phoneme prefix to words.
    pub trie: Trie,
    /// Forward index — word to all known pronunciations.
    by_word: HashMap<String, Vec<Pronunciation>>,
}

/// Source-preference order used by [`Corpus::preferred_ipa`]. The
/// first source whose name *contains* one of these substrings wins.
/// Matches the Ruby gem's `SourcesByPreference` order.
const SOURCE_PREFERENCE: &[&str] = &["wiktionary", "cmu", "phonemicchart"];

impl Corpus {
    /// Parse the JSON corpus and build both forward and reverse
    /// indexes in a single pass.
    pub fn from_json(json: &str, max_rarity: Option<f64>) -> Result<Self, Error> {
        let raw: HashMap<String, RawEntry> = serde_json::from_str(json)?;
        let mut trie = Trie::default();
        let mut by_word: HashMap<String, Vec<Pronunciation>> = HashMap::new();
        for (word, entry) in raw {
            if let (Some(rarity), Some(cap)) = (entry.rarity, max_rarity) {
                if rarity > cap {
                    continue;
                }
            }
            let mut entries: Vec<Pronunciation> = Vec::with_capacity(entry.ipa.len());
            for (source, ipa) in entry.ipa {
                if ipa.is_empty() {
                    continue;
                }
                entries.push(Pronunciation {
                    word: word.clone(),
                    ipa,
                    source,
                    rarity: entry.rarity,
                    alt_display: entry.alt_display.clone(),
                });
            }
            for p in &entries {
                trie.insert(p.clone());
            }
            if !entries.is_empty() {
                by_word.insert(word, entries);
            }
        }
        Ok(Self { trie, by_word })
    }

    /// All registered pronunciations of `word`, in original-source
    /// order. Returns an empty slice for unknown words.
    pub fn pronunciations(&self, word: &str) -> &[Pronunciation] {
        self.by_word
            .get(word)
            .map(Vec::as_slice)
            .unwrap_or(&[])
    }

    /// The "best" IPA transcription for `word`: the first source
    /// whose label matches the [`SOURCE_PREFERENCE`] order, falling
    /// back to whatever appears first in the corpus.
    pub fn preferred_ipa(&self, word: &str) -> Option<&str> {
        let prs = self.pronunciations(word);
        for pref in SOURCE_PREFERENCE {
            if let Some(p) = prs.iter().find(|p| p.source.contains(pref)) {
                return Some(&p.ipa);
            }
        }
        prs.first().map(|p| p.ipa.as_str())
    }

    /// Transcribe an English phrase to a concatenated IPA stream.
    /// Words are lowercased before lookup. Returns `None` if any word
    /// has no transcription in the corpus.
    pub fn transcribe(&self, phrase: &str) -> Option<String> {
        let mut out = String::new();
        for word in phrase.split_whitespace() {
            let key = word.to_lowercase();
            // Strip simple trailing punctuation common in input.
            let key = key.trim_end_matches(|c: char| matches!(c, '.' | ',' | '!' | '?' | ';' | ':'));
            let ipa = self.preferred_ipa(key)?;
            out.push_str(ipa);
        }
        Some(out)
    }

    /// Number of distinct headwords in the corpus.
    pub fn word_count(&self) -> usize {
        self.by_word.len()
    }
}

/// Stateful iterator over a trie walk anchored at a single offset.
struct TrieWalk<'a> {
    node: Option<&'a Node>,
    chars: &'a [char],
    offset: usize,
    depth: usize,
    /// Index into the current node's `terminations` list. Each call to
    /// `next()` yields one entry from there before advancing the walk.
    term_idx: usize,
    yielded_root_terminations: bool,
}

impl<'a> Iterator for TrieWalk<'a> {
    type Item = (usize, &'a Pronunciation);

    fn next(&mut self) -> Option<Self::Item> {
        loop {
            let node = self.node?;
            // The root node itself can hold an "empty word" termination
            // in pathological corpora; skip those to avoid yielding
            // zero-length matches.
            let skip_root = !self.yielded_root_terminations && self.depth == 0;
            if !skip_root && self.term_idx < node.terminations.len() {
                let p = &node.terminations[self.term_idx];
                self.term_idx += 1;
                return Some((self.depth, p));
            }
            if self.depth == 0 {
                self.yielded_root_terminations = true;
            }
            // Advance one character deeper.
            let pos = self.offset + self.depth;
            if pos >= self.chars.len() {
                return None;
            }
            let ch = self.chars[pos];
            self.node = node.children.get(&ch).map(|b| b.as_ref());
            self.depth += 1;
            self.term_idx = 0;
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    const TINY: &str = r#"{
        "cat":  { "rarity": 100, "ipa": { "cmu": "kæt" }, "alt_display": "CAT" },
        "cats": { "rarity": 250, "ipa": { "cmu": "kæts" } },
        "kit":  { "rarity": 500, "ipa": { "cmu": "kɪt" } },
        "dog":  { "rarity": 90,  "ipa": { "cmu": "dɔg" } }
    }"#;

    #[test]
    fn parses_corpus() {
        let t = Trie::from_json(TINY, None).unwrap();
        assert_eq!(t.len(), 4);
    }

    #[test]
    fn max_rarity_drops_the_tail() {
        let t = Trie::from_json(TINY, Some(200.0)).unwrap();
        // Only "cat" (100) and "dog" (90) survive.
        assert_eq!(t.len(), 2);
    }

    #[test]
    fn finds_words_starting_at_a_position() {
        let t = Trie::from_json(TINY, None).unwrap();
        let stream: Vec<char> = "kæts".chars().collect();
        let hits: Vec<_> = t.words_starting_at(&stream, 0).collect();
        let words: Vec<&str> = hits.iter().map(|(_, p)| p.word.as_str()).collect();
        // Both "cat" (3 chars) and "cats" (4 chars) should match.
        assert!(words.contains(&"cat"));
        assert!(words.contains(&"cats"));
    }

    #[test]
    fn reports_consumed_char_count_correctly() {
        let t = Trie::from_json(TINY, None).unwrap();
        let stream: Vec<char> = "kæts".chars().collect();
        for (consumed, p) in t.words_starting_at(&stream, 0) {
            assert_eq!(consumed, p.ipa.chars().count());
        }
    }

    #[test]
    fn no_match_when_prefix_diverges() {
        let t = Trie::from_json(TINY, None).unwrap();
        let stream: Vec<char> = "fʌn".chars().collect();
        let hits: Vec<_> = t.words_starting_at(&stream, 0).collect();
        assert!(hits.is_empty());
    }

    #[test]
    fn corpus_supports_forward_lookup_and_transcribe() {
        let c = Corpus::from_json(TINY, None).unwrap();
        assert_eq!(c.word_count(), 4);
        assert_eq!(c.preferred_ipa("cat"), Some("kæt"));
        assert_eq!(c.preferred_ipa("dog"), Some("dɔg"));
        assert_eq!(c.preferred_ipa("not_there"), None);
        // Transcription of a phrase concatenates per-word IPA.
        assert_eq!(c.transcribe("cat dog"), Some("kætdɔg".to_string()));
        assert_eq!(c.transcribe("Cat Dog"), Some("kætdɔg".to_string())); // case-insensitive
        // Unknown word → None
        assert_eq!(c.transcribe("cat orange"), None);
    }

    #[test]
    fn corpus_trie_field_walks_correctly() {
        let c = Corpus::from_json(TINY, None).unwrap();
        let stream: Vec<char> = "kæts".chars().collect();
        let words: Vec<&str> = c
            .trie
            .words_starting_at(&stream, 0)
            .map(|(_, p)| p.word.as_str())
            .collect();
        assert!(words.contains(&"cat"));
        assert!(words.contains(&"cats"));
    }
}
