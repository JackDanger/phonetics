# Changelog

All notable changes to the phonetics project are recorded here. The
three published packages (`phonetics-rs` on crates.io,
`phonetics-ipa` on PyPI, `phonetics` on RubyGems) share this history
because they share the same Rust core.

This project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html);
the gem's `4.x` lineage is independent of the `0.x` lineage on the
other two registries (RubyGems doesn't allow downgrades from the
prior C-extension gem's `3.x`).

## [Unreleased]

## [0.3.1] — 2026-05-12 (`phonetics-rs` only)

### Fixed
- `Corpus::preferred_ipa` no longer non-deterministically returns
  `cmu2` (or `wikipron2`, etc.) when the canonical `cmu` entry is
  also present. The earlier implementation used `source.contains(...)`,
  which matches indexed variants too; combined with random HashMap
  iteration order this made the result of `preferred_ipa` depend on
  the process-wide hash seed. Now each preference is tried as an
  exact match first and only falls through to prefix matching when
  no exact match exists.

### Changed
- `SOURCE_PREFERENCE` extended with the new corpus labels
  (`misaki_gold`, `misaki_silver`, `wikipron`) while keeping the old
  labels (`phonemicchart`, `wiktionary`) for backward compatibility.
  Existing corpora resolve identically; new corpora built with the
  fused-source pipeline (see madgab `corpus/build.py`) get clean
  resolution out of the box.

## [0.3.0] — 2026-05-12 (`phonetics-rs` only)

### Added — Rust core (`phonetics-rs`)
- `Trie::words_approximately_starting_at` (feature `transcriptions`):
  budgeted DFS through the transcription trie that allows per-
  character phonetic substitution while staying inside a caller-
  supplied cost budget. Designed for use by the
  [madgab](https://github.com/JackDanger/madgab) Mad Gab generator.

### Changed — Python wheel (internal only)
- pyo3 0.22 → 0.24. No behaviour change; quieter deprecation warnings
  on Python 3.13. The published `phonetics-ipa` wheel version stays
  at 0.2.0 because no Python-visible surface changed.

### Notes
- The Ruby gem and Python wheel don't yet expose the `transcriptions`
  module to their host languages, so this release ships only on
  crates.io. The unified release workflow runs all three registry
  jobs on the `v0.3.0` tag, but the PyPI / RubyGems uploads no-op
  via `skip-existing` because their versions are unchanged.

## [0.2.0] — 2026-05-12

The first published release across all three registries. Established
the Rust core + Magnus (Ruby) + PyO3 (Python) layout the project ships
in.

### Added — Rust core (`phonetics-rs`)
- Per-phoneme acoustic distance: `phonetics::distance(a, b)`.
- Strict edit distance with Damerau transposition:
  `phonetics::levenshtein(a, b)`.
- Listener-confusion distance: `phonetics::confusion(a, b)` —
  Gotoh affine-gap DP, weak-phoneme indel discount, empirical
  confusion overlay calibrated against Mad Gab puzzle data and
  West Coast American English.
- Normalised similarity: `phonetics::similarity(a, b)`.
- IPA tokenizer with diacritic absorption: `phonetics::tokens(input,
  boundaries)`.
- Vowel module: Bark-Euclidean distance with rounding/rhoticity
  penalties.
- Consonant module: voicing + manner + 2D place + lateral feature.
- Compound phonemes (diphthongs, affricates) as atomic units.
- Cross-class bridge (approximant↔vowel, glottal↔vowel) replacing
  the prior hard 1.0 fallback.
- `transcriptions` feature (initially feature-flagged off):
  `Trie::from_json` and `Corpus::from_json` for English-word lookup
  by either spelling or IPA prefix.

### Added — Ruby binding (`phonetics` gem 4.0.0)
- Magnus-backed native extension replacing the prior hand-written C
  extension. Same public surface (`Phonetics.distance`,
  `Phonetics.confusion`, `Phonetics.levenshtein`,
  `Phonetics.similarity`, `Phonetics.sub_cost`, `Phonetics.tokenize`).
- 6 platform-native gems shipped (arm64-darwin, x86_64-darwin,
  x86_64-linux, x86_64-linux-musl, aarch64-linux, x64-mingw-ucrt)
  plus the source gem.

### Added — Python binding (`phonetics-ipa` wheel 0.2.0)
- PyO3 + maturin packaging. ABI3-py39 wheel — one wheel per platform
  runs on CPython 3.9+.
- API mirrors the Rust crate: `phonetics.distance`, `.confusion`,
  `.levenshtein`, `.similarity`, `.sub_cost`, `.tokenize`.

### Notes
- The Ruby gem keeps the bare `phonetics` name. The Rust crate is
  `phonetics-rs` and the Python wheel is `phonetics-ipa` because the
  unqualified names are held by unrelated projects on those
  registries. In code all three import as `phonetics`.

## [0.1.0] and earlier

The pre-rewrite Ruby+C lineage of the gem (`phonetics` 3.x.x) lives
in the git history. v0.2.0 above is the first release of the Rust-
based architecture.
