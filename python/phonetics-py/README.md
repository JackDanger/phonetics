# phonetics

IPA-based phonetic distance for Python, built on a Rust core.

## Install

```bash
pip install phonetics-ipa
```

The PyPI package is `phonetics-ipa` (the bare `phonetics` name is held
by an unrelated metaphone library). The importable module is still
`phonetics`:

```python
import phonetics
```

## Usage

```python
import phonetics

# Strict per-phoneme acoustic distance, 0..1
phonetics.distance("p", "b")          # 0.15  (voicing flip)
phonetics.distance("ɑ", "ɔ")          # ~0.21 (acoustically distinct)

# Listener-confusion distance, Mad Gab calibrated
target = "ɪtsdʒʌstəstupɪdgeɪm"        # "It's just a stupid game"
clue   = "hɪtsdʒʌstɪsduphɪdkeɪm"      # "Hits Justice Dupe Hid Came"
phonetics.confusion(target, clue)     # ~0.77
phonetics.similarity(target, clue)    # ~0.96  (high listener overlap)

# Perceptual per-phoneme (with empirical confusion overlay)
phonetics.sub_cost("t", "ɾ")          # ~0.10 (American t-flapping)
phonetics.sub_cost("ɑ", "ɔ")          # ~0.05 (cot/caught merger, WCE)

# Tokenisation
phonetics.tokenize("kɑɪt")            # ['k', 'ɑɪ', 't']  (diphthong atomic)
phonetics.tokenize("it is", boundaries=True)  # ['i', 't', '#', 'i', 's']
```

See <https://github.com/JackDanger/phonetics> for the extended write-up
of the metric design and the parity tests against Mad Gab puzzles.

## License

MIT.
