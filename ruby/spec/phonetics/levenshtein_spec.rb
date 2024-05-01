# frozen_string_literal: true

require_relative '../../lib/phonetics/levenshtein'

RSpec.describe Phonetics::Levenshtein do
  include_examples 'calculates levenshtein distance'
end
