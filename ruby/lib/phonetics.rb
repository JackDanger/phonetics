# frozen_string_literal: true

# Phonetics: tools for working with the International Phonetic Alphabet.
#
# Two-tier distance API:
#
#   * Phonetics::Levenshtein.distance(ipa1, ipa2)
#     Strict weighted edit-distance over IPA phonemes. Each substitution
#     costs Phonetics.distance(a, b) (Bark-space vowel distance + structured
#     consonant feature distance + cross-class bridge + diacritic
#     mismatches). Each indel costs 1.0. Use this when you want raw
#     acoustic distance — clustering accents, dialect work, ASR error
#     analysis. Backed by a fast C extension.
#
#   * Phonetics::Confusion.distance(ipa1, ipa2)
#     Listener-confusion distance, calibrated against Mad Gab puzzle data.
#     Uses Gotoh's affine-gap algorithm so multi-phoneme re-syllabification
#     at word boundaries doesn't pay full per-phoneme cost, plus an explicit
#     weak-phoneme discount for /ə/, /h/, /ʔ/, /ɦ/ (which native English
#     listeners drop, insert, and hallucinate without much perceptual
#     awareness). Use this when you want perceptual similarity — Mad Gab
#     solving, pun detection, mondegreen analysis, mishearing modelling.
#     Pure Ruby; slower than the strict path but still tractable on
#     phrase-sized input.
#
# Both metrics share the same per-phoneme cost (Phonetics.distance), so
# improvements to the underlying acoustic model propagate to both layers.
require 'phonetics/distances'
require 'phonetics/levenshtein'
require 'phonetics/confusion'
require 'phonetics/transcriptions'
