require_relative '../../lib/phonetics/levenshtein'

RSpec.describe Phonetics::Levenshtein do
  include_examples "calculates levenshtein distance"
end
