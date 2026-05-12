"""
phonetics — IPA-based phonetic distance.

A thin Python facade over the Rust `phonetics` crate (loaded as the
`phonetics._native` submodule via PyO3). Same two-tier API as the
Ruby gem and the Rust crate:

  phonetics.distance(p1, p2)       acoustic per-phoneme, 0..1
  phonetics.levenshtein(s1, s2)    strict edit distance
  phonetics.confusion(s1, s2)      listener-confusion distance
  phonetics.similarity(s1, s2)     normalised 0..1
  phonetics.sub_cost(p1, p2)       perceptual per-phoneme
  phonetics.tokenize(ipa, boundaries=False)   phoneme stream

Strict (`distance`, `levenshtein`) is the right call for objective
acoustic-distance work. Confusion (`confusion`, `similarity`) is tuned
to native English (West Coast American) listener perception — Mad
Gab, puns, mishearings. See the parent repository's README for an
extended write-up of the metric.
"""

from phonetics._native import (
    distance,
    confusion,
    levenshtein,
    similarity,
    sub_cost,
    tokenize,
)

__all__ = [
    "distance",
    "confusion",
    "levenshtein",
    "similarity",
    "sub_cost",
    "tokenize",
]

__version__ = "0.1.0"
