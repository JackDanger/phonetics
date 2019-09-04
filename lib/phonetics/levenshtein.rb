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

    def self.distance(str1, str2, verbose = false)
      internal_phonetic_distance(str1, str2, verbose)
    end
  end
end
