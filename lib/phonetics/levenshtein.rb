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

    def self.distance(str1, str2, block_size = 1, max_distance = 10)
      internal_phonetic_distance(
        str1.unpack("U*"), str2.unpack("U*"),
        block_size, max_distance
      )
    end

    def self.string_distance(*args)
      distance(*args)
    end

    def self.array_distance(array1, array2, block_size = 1, max_distance = 10)
      internal_phonetic_distance(array1, array2, block_size, max_distance)
    end

    # keep backward compatibility - internal_distance was called distance_utf
    # before
    def self.distance_utf(*args)
      internal_phonetic_distance(*args)
    end
  end
end
