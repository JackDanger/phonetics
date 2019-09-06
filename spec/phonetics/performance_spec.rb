# frozen_string_literal: true

require_relative '../../lib/phonetics/levenshtein'
require_relative '../../lib/phonetics/ruby_levenshtein'

require 'benchmark'
RSpec.describe Phonetics do
  context 'performance' do
    let(:ruby_timing) do
      Benchmark.measure do
        iterations.times { Phonetics::RubyLevenshtein.distance(phoneme1, phoneme2) }
      end.real
    end
    let(:c_timing) do
      Benchmark.measure do
        iterations.times { Phonetics::Levenshtein.distance(phoneme1, phoneme2) }
      end.real
    end

    let(:iterations) { 1_000 }

    context 'for short sequences' do
      let(:phoneme1) { 'kuɹzlɑɪt' }
      let(:phoneme2) { 'bədlɑɪt' }

      it 'completes much faster than the Ruby version' do
        puts "Difference on short strings: #{ruby_timing / c_timing}"
        expect(c_timing * 60).to be < ruby_timing
      end
    end

    context 'for long sequences' do
      let(:phoneme1) { 'kuɹzlɑɪtizgʊdfɔɹju' }
      let(:phoneme2) { 'bədlɑɪtizməfeɪvɹɪtbɪɝ' }

      it 'completes much faster than the Ruby version' do
        puts "Difference on long strings: #{ruby_timing / c_timing}"
        # TODO: make this at least 100x faster than Ruby. There must be some
        # allocations we're  missing.
        expect(c_timing * 30).to be < ruby_timing
      end
    end
  end
end
