# phonetics

IPA-based phonetic distance metrics. One Rust core, three packages.

| Package | Registry name | Manifest | Registry |
|---|---|---|---|
| Rust crate | `phonetics-rs` | [`rust/phonetics`](rust/phonetics) | crates.io |
| Ruby gem | `phonetics` | [`ruby/`](ruby) (Magnus binding at `ruby/ext/phonetics_ruby/`) | RubyGems |
| Python wheel | `phonetics-ipa` | [`python/phonetics-py/`](python/phonetics-py) (PyO3 binding) | PyPI |

The Rust crate is `phonetics-rs` and the Python package is `phonetics-ipa`
because the bare `phonetics` name is taken on both registries by unrelated
projects. The Ruby gem keeps the bare name because it's a continuation of
the prior 3.x line. In code you still write `use phonetics::…`,
`import phonetics`, and `Phonetics.…` respectively.

## The metric

Two scores live in this library:

* **Strict phonetic distance** — acoustic-distance edit metric. Bark-space
  vowel distance, 2D consonant place embedding, approximant–vowel bridge,
  diphthong/affricate handling, Damerau-Levenshtein edit distance with
  fixed indel cost. The right call for accent clustering, dialect work,
  ASR error analysis.

* **Listener-confusion distance** — Mad-Gab-tuned perceptual metric.
  Gotoh affine-gap DP on top of the same per-phoneme cost basis, plus a
  weak-phoneme indel discount (/ə/, /h/, /ʔ/, /ɦ/), a word-boundary
  discount (re-syllabification is the operation Mad Gab encodes), and an
  empirical confusion overlay calibrated against West Coast American
  English. The right call for Mad Gab solving, pun detection, mondegreen
  analysis.

Both metrics share the same per-phoneme cost. Improvements to the
acoustic model propagate to both.

## Use it

```rust
// Rust
let d = phonetics::confusion("ɪtsdʒʌstəstupɪdgeɪm", "hɪtsdʒʌstɪsduphɪdkeɪm");
```

```ruby
# Ruby
Phonetics.confusion("ɪtsdʒʌstəstupɪdgeɪm", "hɪtsdʒʌstɪsduphɪdkeɪm")
```

```python
# Python
import phonetics
phonetics.confusion("ɪtsdʒʌstəstupɪdgeɪm", "hɪtsdʒʌstɪsduphɪdkeɪm")
```

Same number out of all three — they share a binary.

## Repository layout

```
phonetics/
├── rust/
│   ├── Cargo.toml          # workspace
│   └── phonetics/          # the core crate, publishable to crates.io
├── ruby/
│   ├── lib/                # thin Ruby facade
│   ├── ext/phonetics/      # Magnus binding crate; built by extconf.rb
│   └── spec/               # rspec
├── python/phonetics-py/
│   ├── src/                # PyO3 binding crate
│   ├── python/phonetics/   # pure-Python facade
│   └── tests/              # pytest
└── .github/workflows/
    ├── test.yml            # cargo + rspec + pytest on every PR
    └── publish.yml         # crates.io + RubyGems + PyPI on git tag
```

## License

MIT.
