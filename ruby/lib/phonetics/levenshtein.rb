# frozen_string_literal: true

require_relative '../phonetics'
require_relative 'c_levenshtein'

# Using the Damerau version of the Levenshtein algorithm, with phonetic feature
# count used instead of a binary edit distance calculation
#
# This implementation was dually inspired by the damerau-levenshtein gem
# (https://github.com/GlobalNamesArchitecture/damerau-levenshtein/tree/master/ext/damerau_levenshtein).
# and "Using Phonologically Weighted Levenshtein Distances for the Prediction
# of Microscopic Intelligibility" by Lionel Fontan, Isabelle Ferrané, Jérôme
# Farinas, Julien Pinquier, Xavier Aumont, 2016
# https://hal.archives-ouvertes.fr/hal-01474904/document
module Phonetics
  module Levenshtein
    extend ::PhoneticsLevenshteinCBinding

    # The C path uses the same per-phoneme cost convention as the Ruby
    # implementation. Indel and transposition constants are exposed here so
    # tests and downstream code can reference one canonical value.
    INDEL_COST     = 1.0
    TRANSPOSE_COST = 0.8

    # NOTE: The C tokenizer recognises base phonemes (and atomic compounds
    # such as /tʃ/, /aɪ/) but *not* suprasegmental diacritics (ː, ʰ, ˈ, …).
    # Diacritic-bearing input produces slightly different results between the
    # two implementations: the C path drops the diacritic and treats the base
    # phonemes as identical, while RubyLevenshtein charges a small additive
    # mismatch cost. Use RubyLevenshtein when diacritic fidelity matters; use
    # the C path when raw throughput on stripped phonemic transcriptions is
    # the priority.
    #
    # rubocop:disable Style/OptionalBooleanParameter
    def self.distance(str1, str2, verbose = false)
      return if str1.nil? || str2.nil?

      internal_phonetic_distance(str1, str2, verbose)
    end
    # rubocop:enable Style/OptionalBooleanParameter
  end
end
