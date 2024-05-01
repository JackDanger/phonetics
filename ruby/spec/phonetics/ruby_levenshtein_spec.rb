# frozen_string_literal: true

require_relative '../../lib/phonetics/ruby_levenshtein'

RSpec.describe Phonetics::RubyLevenshtein do
  include_examples 'calculates levenshtein distance'
end
