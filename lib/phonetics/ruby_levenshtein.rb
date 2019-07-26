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
  class RubyLevenshtein

    MIN_EDIT_DISTANCE = 0.01

    def initialize(ipa_str1, ipa_str2)
      @str1 = ipa_str1
      @str2 = ipa_str2
      @len1 = ipa_str1.size
      @len2 = ipa_str2.size
      ensure_is_phonetic!
      prepare_matrix
      set_edit_distances(ipa_str1, ipa_str2)
    end

    def distance
      return 0 if walk.empty?
      walk.last[:distance]
    end

    def self.distance(str1, str2)
      new(str1, str2).distance
    end

    private

    def ensure_is_phonetic!
      [@str1, @str2].each do |string|
        string.chars.each do |char|
          unless Phonetics.phonemes.include?(char)
            raise ArgumentError, "#{char.inspect} is not a character in the International Phonetic Alphabet. #{self.class.name} only works with IPA-transcribed strings"
          end
        end
      end
    end

    def walk
      res = []
      i, j = @len2, @len1
      return res if i == 0 && j == 0
      begin
        i, j, char = char_data(i, j)
        res.unshift char
      end while i > 0 && j > 0
      res
    end

    def set_edit_distances(str1, str2)
      i = 0
      while (i += 1) <= @len2
        j = 0
        while (j += 1) <= @len1
          # This is where we implement the modifications to Damerau-Levenshtein
          # according to https://hal.archives-ouvertes.fr/hal-01474904/document
          options = [
            del(i, j) + deletion_cost(i, j),
            ins(i, j) + insertion_cost(i, j),
            subst(i, j) + substitution_cost(i, j),
          ]
          best = options.min

          # If we're comparing two identical phonemes, take the shortcut of
          # reusing the previous (diagonally upper-left) value.
          if str2[i - 1] == str1[j - 1] && no_change(i, j) <= best
            best = no_change(i, j)
          end
          @matrix[i][j] = best
        end
      end
    end

    def char_data(i, j)
      char = { distance: @matrix[i][j] }
      operation, move = find_previous(i, j)
      previous_value = move[:value]
      char[:type] = previous_value == char[:distance] ? :same : operation
      i, j = move[:move_to]
      [i, j, char]
    end

    def find_previous(i, j)
      [
        [ :insert, { cost: ins(i, j), move_to: [i, j - 1] }],
        [ :delete, { cost: del(i, j), move_to: [i, j - 1] }],
        [ :substitute, { cost: subst(i, j), move_to: [i, j - 1] }],
      ].select do |operation, data|
        # Don't send us out of bounds
        data[:move_to][0] >= 0 && data[:move_to][1] >= 0
      end.sort_by do |operation, data|
        # pick the cheapest one
        data[:value]
      end.first
    end

    # TODO: Score the edit distance lower if sonorant sounds are found in sequence.
    def del(i, j)
      @matrix[i - 1][j]
    end

    def deletion_cost(i, j)
      prev_phoneme = @str2[i - 1]
      current_phoneme = @str1[j - 1]
      [ Phonetics.distance(prev_phoneme, current_phoneme), MIN_EDIT_DISTANCE ].max
    end

    def ins(i, j)
      @matrix[i][j - 1]
    end

    def insertion_cost(i, j)
      prev_phoneme = @str1[j - 1]
      current_phoneme = @str2[i - 1]
      [ Phonetics.distance(prev_phoneme, current_phoneme), MIN_EDIT_DISTANCE ].max
    end

    def subst(i, j)
      @matrix[i - 1][j - 1]
    end

    def substitution_cost(i, j)
      [ Phonetics.distance(@str1[j - 1], @str2[i - 1]), MIN_EDIT_DISTANCE ].max
    end

    def no_change(i, j)
      @matrix[i - 1][j - 1]
    end

    # Set the minimum scores equal to the distance between each phoneme,
    # sequentially.
    #
    # The first value is always zero.
    # The second value is always the phonetic distance between the first
    # phonemes of each string.
    # Subsequent values are the cumulative phonetic distance between each
    # phoneme within the same string.
    # "aek" -> [0, 1, 1.61, 2.61]
    def initial_distances(str1, str2)
      if @len1 == 0 || @len2 == 0
       distance_between_first_phonemes = 0
      else
       distance_between_first_phonemes = Phonetics.distance(str1[0], str2[0])
      end

      distances1 = (1..(str1.length-1)).reduce([0, distance_between_first_phonemes]) do |acc, i|
        acc << acc.last + Phonetics.distance(str1[i-1], str1[i])
      end
      distances2 = (1..(str2.length-1)).reduce([0, distance_between_first_phonemes]) do |acc, i|
        acc << acc.last + Phonetics.distance(str2[i-1], str2[i])
      end

      [ distances1, distances2 ]
    rescue => e
      require 'pry'
      binding.pry
      p e
    end

    def prepare_matrix
      str1_initial, str2_initial = initial_distances(@str1, @str2)

      @matrix = Array.new(@len2 + 1) { Array.new(@len1 + 1) { nil } }
      # The first row is the initial values for @str2
      @matrix[0] = str1_initial
      # The first column is the initial values for @str1
      @len2.times { |n| @matrix[n + 1][0] = str2_initial[n] }
    end

    def print_matrix
      puts "        #{@str1.chars.map {|c| c.ljust(6, " ") }.join}"
      @matrix.each_with_index do |row, ridx|
        print '  ' if ridx == 0
        print "#{@str2[ridx - 1]} " if ridx > 0
        row.each_with_index do |cell, cidx|
          if cell
            cell_string = cell.to_s[0, 4]
            if cidx == @len1
              print cell_string
            else
              print (cell_string + ",").ljust(6, " ")
            end
          else
            print " " * 6
          end
        end
        puts ''
      end
      ''
    end
  end
end
