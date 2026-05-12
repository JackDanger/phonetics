# frozen_string_literal: true

# Phonetics — IPA-based phonetic distance.
#
# The entire algorithmic core is written in Rust (see <repo>/rust/
# phonetics) and loaded as a native extension via Magnus. This file
# layers ergonomic Ruby idioms on top of the bare module functions
# that the extension exports.
#
# Two-tier distance API:
#
#   Phonetics.distance(p1, p2)              acoustic per-phoneme, 0..1
#   Phonetics.levenshtein(s1, s2)           strict edit distance
#   Phonetics.confusion(s1, s2)             listener-confusion distance
#   Phonetics.similarity(s1, s2)            normalised 0..1
#   Phonetics.sub_cost(p1, p2)              perceptual per-phoneme
#   Phonetics.tokenize(ipa, boundaries:)    phoneme stream
require 'delegate'

require_relative 'phonetics/phonetics_ruby'
require_relative 'phonetics/transcriptions'

module Phonetics
  # The native binding exposes the tokenizer as `_tokenize(input,
  # boundaries)`. Magnus's `function!` macro doesn't bridge Ruby
  # keyword arguments through to Rust, so we wrap it in a Ruby method
  # that does accept the kwarg.
  def self.tokenize(input, boundaries: false)
    _tokenize(input, boundaries)
  end

  # ------------------------------------------------------------------
  # Phonetics::String — iterator over phonemes in an IPA string.
  # ------------------------------------------------------------------
  class String < SimpleDelegator
    def each_phoneme(boundaries: false)
      Phonetics.tokenize(to_s, boundaries: boundaries).each
    end
  end

  # ------------------------------------------------------------------
  # Backwards-compatible namespaced API.
  #
  # The previous Ruby+C implementation exposed these under sub-modules.
  # Keep them as thin delegators so existing callers don't break —
  # there's nothing interesting happening here, just forwarding.
  # ------------------------------------------------------------------

  module Levenshtein
    INDEL_COST     = 1.0
    TRANSPOSE_COST = 0.8

    def self.distance(s1, s2, _verbose = false)
      return if s1.nil? || s2.nil?

      Phonetics.levenshtein(s1, s2)
    end
  end

  module Confusion
    GAP_OPEN             = 0.60
    GAP_EXTEND           = 0.25
    WEAK_INDEL_COST      = 0.15
    BOUNDARY_INDEL_COST  = 0.02

    def self.distance(s1, s2, verbose: false)
      _ = verbose
      Phonetics.confusion(s1, s2)
    end

    def self.similarity(s1, s2)
      Phonetics.similarity(s1, s2)
    end

    def self.sub_cost(a, b)
      Phonetics.sub_cost(a, b)
    end
  end
end
