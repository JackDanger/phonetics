# frozen_string_literal: true

require_relative '../phonetics'

# Damerau-Levenshtein distance over IPA phonemes, with the per-phoneme cost
# coming from Phonetics.distance.
#
# Recurrence (standard form):
#
#   d[i][j] = min(
#     d[i-1][j]   + INDEL_COST,                    # delete s1[i-1]
#     d[i][j-1]   + INDEL_COST,                    # insert s2[j-1]
#     d[i-1][j-1] + sub_cost(s1[i-1], s2[j-1]),    # substitute
#     d[i-2][j-2] + TRANSPOSE_COST                 # adjacent transposition
#   )
#
# `sub_cost` is the phoneme-distance metric in lib/phonetics/distances.rb and
# is 0 for identical phonemes. INDEL_COST is fixed at 1.0 so an insertion of
# one phoneme costs exactly one indel regardless of its neighbours — the old
# implementation accumulated intra-string distances along the seed row, which
# made indel cost depend on what the inserted phoneme happened to sit next
# to. TRANSPOSE_COST is fixed at 0.8 (Damerau): swapping adjacent phonemes is
# cheaper than two separate substitutions, because in Mad Gab perception
# adjacent-phoneme order is famously fluid (/stuː/ ↔ /tsuː/, /æsk/ ↔ /æks/).
module Phonetics
  class RubyLevenshtein
    INDEL_COST     = 1.0
    TRANSPOSE_COST = 0.8

    attr_reader :str1, :str2, :len1, :len2, :matrix

    # rubocop:disable Style/OptionalBooleanParameter
    def initialize(ipa_str1, ipa_str2, verbose = false)
      @str1 = filter_phonemes(ipa_str1)
      @str2 = filter_phonemes(ipa_str2)
      @len1 = @str1.size
      @len2 = @str2.size
      @verbose = verbose
      prepare_matrix
      compute_matrix
    end

    def self.distance(str1, str2, verbose = false)
      new(str1, str2, verbose).distance
    end
    # rubocop:enable Style/OptionalBooleanParameter

    def distance
      return 0 if len1.zero? && len2.zero?

      print_matrix if @verbose
      matrix[len2][len1]
    end

    private

    # Tokenise the input down to recognised phonemes. Anything else is
    # discarded so non-IPA characters don't smuggle themselves in as
    # zero-cost matches.
    def filter_phonemes(str)
      Phonetics::String.new(str).each_phoneme.to_a
    end

    def compute_matrix
      (1..len2).each do |i|
        (1..len1).each do |j|
          # Note: in this matrix, i indexes str2 (rows) and j indexes str1
          # (cols). s1[j-1] and s2[i-1] are the phonemes the recurrence
          # compares at this cell.
          a = str1[j - 1]
          b = str2[i - 1]

          sub_cost   = Phonetics.distance(a, b)
          delete     = matrix[i - 1][j]     + INDEL_COST
          insert     = matrix[i][j - 1]     + INDEL_COST
          substitute = matrix[i - 1][j - 1] + sub_cost

          best = [delete, insert, substitute].min

          # Damerau adjacent-transposition: only valid when both strings have
          # at least two phonemes here and they're swapped.
          if i > 1 && j > 1 && a == str2[i - 2] && b == str1[j - 2]
            transpose = matrix[i - 2][j - 2] + TRANSPOSE_COST
            best = transpose if transpose < best
          end

          matrix[i][j] = best

          if @verbose
            puts "------- #{j}/#{i} #{j + (i * (len1 + 1))}"
            print_matrix
          end
        end
      end
    end

    def prepare_matrix
      @matrix = Array.new(len2 + 1) { Array.new(len1 + 1, 0.0) }
      # Seed: matching the empty string against the first j phonemes of str1
      # costs j indels; symmetric for str2 down the left column.
      (1..len1).each { |j| @matrix[0][j] = j * INDEL_COST }
      (1..len2).each { |i| @matrix[i][0] = i * INDEL_COST }
    end

    # Developer aid for tracing the recurrence step-by-step.
    def print_matrix
      puts "           #{str1.map { |c| c.ljust(9, ' ') }.join}"
      matrix.each_with_index do |row, ridx|
        print '  ' if ridx == 0
        print "#{str2[ridx - 1]} " if ridx > 0
        row.each do |cell|
          cell ||= 0.0
          print cell.to_s[0, 8].ljust(8, '0')
          print ' '
        end
        puts ''
      end
      ''
    end
  end
end
