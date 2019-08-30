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

    def self.codepoints(string)
      puts "rubyland string: #{string} @ #{string.object_id}"
      puts "rubyland string bytes: #{string.bytes.inspect}"
      testing_codepoints(string)
    end

    def self.distance(str1, str2, verbose = false)
      ensure_is_phonetic!(str1, str2)
      internal_phonetic_distance(
        Phonetics.as_utf_8_long(str1),
        Phonetics.as_utf_8_long(str2),
        verbose
      )
    end

    def self.ensure_is_phonetic!(str1, str2)
      [str1, str2].each do |string|
        string.chars.each do |char|
          unless Phonetics.phonemes.include?(char)
            msg = "#{char.inspect} is not a character in the International Phonetic Alphabet. #{self.class.name} only works with IPA-transcribed strings"
            raise ArgumentError, msg
          end
        end
      end
    end
  end
end
