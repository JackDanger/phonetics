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

## Status

Pre-1.0. Core data tables and the per-phoneme acoustic distance are
parity-tested against the Ruby reference. Levenshtein and Confusion DPs
are landing module-by-module.

## License

MIT.
