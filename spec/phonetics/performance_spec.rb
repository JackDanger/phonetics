# frozen_string_literal: true

require_relative '../../lib/phonetics/levenshtein'
require_relative '../../lib/phonetics/ruby_levenshtein'

require 'benchmark'
RSpec.describe Phonetics do
  context 'performance' do
    let(:phoneme1) { 'curzlait' }
    let(:phoneme2) { 'bədlait' }
    let(:iterations) { 10 }

    it 'completes much faster than the Ruby version' do
      ruby_timing = Benchmark.measure do
        1_000.times { Phonetics::RubyLevenshtein.distance(phoneme1, phoneme2) }
      end.real
      c_timing = Benchmark.measure do
        1_000.times { Phonetics::Levenshtein.distance(phoneme1, phoneme2) }
      end.real

      expect(c_timing * 4).to be < ruby_timing
    end
  end
end
