require_relative 'c_levenshtein'
# Using the Damerau version of the Levenshtein algorithm, with phonetic feature
# count used instead of a binary edit distance calculation
#
# This implementation is almost entirely taken from the damerau-levenshtein gem
# (https://github.com/GlobalNamesArchitecture/damerau-levenshtein/tree/master/ext/damerau_levenshtein).
# The implementation is modified based on "Using Phonologically Weighted
# Levenshtein Distances for the Prediction of Microscopic Intelligibility" by
# Lionel Fontan, Isabelle Ferrané, Jérôme Farinas, Julien Pinquier, Xavier
# Aumont, 2016
# https://hal.archives-ouvertes.fr/hal-01474904/document
module Phonetics
  module Levenshtein
    extend ::PhoneticsLevenshteinCBinding

    def self.distance(str1, str2)
      internal_phonetic_distance(
        Phonetics.as_utf_8_long(str1),
        Phonetics.as_utf_8_long(str2),
      )
    end
  end
end
