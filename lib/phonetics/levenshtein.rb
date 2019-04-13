require_relative '../phonetics'

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
  class Levenshtein
    def initialize(ipa_str1, ipa_str2)
      @str1 = ipa_str1
      @str2 = ipa_str2
      @len1 = ipa_str1.size
      @len2 = ipa_str2.size
      prepare_matrix
      set_edit_distances(ipa_str1, ipa_str2)
    end

    def distance
      walk.last[:distance]
    end

    def self.distance(str1, str2)
      new(str1, str2).distance
    end

    private

    def walk
      res = []
      cell = [@len2, @len1]
      while cell != [0, 0]
        cell, char = char_data(cell)
        res.unshift char
      end
      res
    end

    def set_edit_distances(str1, str2)
      (1..@len2).each do |i|
        (1..@len1).each do |j|
          no_change(i, j) && next if str2[i - 1] == str1[j - 1]
          @matrix[i][j] = [del(i, j) + 1.0, ins(i, j) + 1.0, subst(i, j)].min
        end
      end
    end

    def char_data(cell)
      char = { distance: @matrix[cell[0]][cell[1]] }
      val = find_previous(cell)
      previous_value = val[0][0]
      char[:type] = previous_value == char[:distance] ? :same : val[1]
      cell = val.pop
      [cell, char]
    end

    def find_previous(cell)
      candidates = [
        [
          [ins(*cell), 1],
          :ins,
          [cell[0], cell[1] - 1],
        ],
        [
          [del(*cell), 2],
          :del,
          [cell[0] - 1, cell[1]],
        ],
        [
          [subst(*cell), 0],
          :subst,
          [cell[0] - 1, cell[1] - 1],
        ],
      ]
      select_cell(candidates)
    end

    def select_cell(candidates)
      candidates.select { |e| e[-1][0] >= 0 && e[-1][1] >= 0 }.
        sort_by(&:first).first
    end

    # TODO: Score the edit distance lower if sonorant sounds are found in sequence.
    def del(i, j)
      @matrix[i - 1][j]
    end

    def ins(i, j)
      @matrix[i][j - 1]
    end

    # This is where we implement the modifications to Damerau-Levenshtein according to
    # https://hal.archives-ouvertes.fr/hal-01474904/document
    def subst(i, j)
      map = Phonetics.distance_map[@str1[j]]
      score = map[@str2[i]] if map
      score ||= 1.0
      @matrix[i - 1][j - 1] + score
    end

    def no_change(i, j)
      @matrix[i][j] = @matrix[i - 1][j - 1]
    end

    def prepare_matrix
      @matrix = []
      @matrix << (0..@len1).to_a
      @len2.times do |i|
        ary = [i + 1] + (1..@len1).map { nil }
        @matrix << ary
      end
    end
  end
end
