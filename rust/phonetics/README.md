# phonetics

IPA-based phonetic distance metrics for Rust.

Two scores live in this crate:

* **`distance(a, b)`** — strict per-phoneme acoustic distance over IPA
  phonemes (Bark-space vowel distance, 2D consonant place embedding,
  approximant–vowel bridge, diphthong/affricate handling).
* **`Confusion::distance(s1, s2)`** — listener-confusion distance over
  whole phonemic strings, calibrated against Mad Gab puzzle data and
  English speech-perception literature.

The split is the point. The first is a claim about the waveform; the
second is a claim about how a listener parses it. They give different
answers to different questions.

This is a port of the Ruby gem of the same name; see the parent
repository for an extended write-up of the metric design.

## Optional `transcriptions` feature

For English-word ⇄ IPA lookup (used by downstream tools like
[madgab](https://github.com/JackDanger/madgab)):

```toml
phonetics-rs = { version = "0.3", features = ["transcriptions"] }
```

```rust
use phonetics::transcriptions::Corpus;
let corpus = Corpus::from_json(&json, Some(20_000.0))?;
corpus.preferred_ipa("cat");           // → Some("kæt")
corpus.transcribe("cat dog");          // → Some("kætdɔg")
// IPA prefix → words that pronounce that prefix
let chars: Vec<char> = "kæt".chars().collect();
for (consumed, p) in corpus.trie.words_starting_at(&chars, 0) {
    println!("{} ({} chars)", p.word, consumed);
}
// Same as above but with a budgeted phonetic-substitution allowance:
let hits = corpus.trie.words_approximately_starting_at(
    &chars, 0, 0.5,
    |a, b| phonetics::distance(&a.to_string(), &b.to_string()),
);
```

The corpus itself is not bundled with this crate — callers pass JSON in
the shape the Ruby `Phonetics::Transcriptions` gem produces.

## Status

The metric (vowels, consonants, cross-class, compounds, diacritics,
Levenshtein, Confusion) is stable and parity-tested against the Ruby
reference. The `transcriptions` feature is newer; see
[CHANGELOG](https://github.com/JackDanger/phonetics/blob/main/CHANGELOG.md).

## License

MIT.
