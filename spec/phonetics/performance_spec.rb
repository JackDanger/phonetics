# frozen_string_literal: true

require 'ruby-prof'
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

    context 'for short sequences' do
      let(:phoneme1) { 'kuɹzlɑɪt' }
      let(:phoneme2) { 'bədlɑɪt' }

      let(:iterations) { 1_000 }

      it 'completes much faster than the Ruby version' do
        puts "Difference on short strings: #{ruby_timing / c_timing}"
        expect(c_timing * 60).to be < ruby_timing
      end
    end

    context 'for long sequences' do
      let(:phoneme1) { 10.times.map { 'kuɹzlɑɪtizgʊdfɔɹju' }.join }
      let(:phoneme2) { 10.times.map { 'bədlɑɪtizməfeɪvɹɪtbɪɝ' }.join }

      let(:iterations) { 100 }

      it 'completes much faster than the Ruby version' do
        # result = RubyProf.profile { c_timing }
        # printer = RubyProf::FlatPrinter.new(result)
        # file = File.open("#{File.basename(__FILE__)}.profile", 'w')
        # printer.print(file , {})
        # file.close()
        # TODO: make this at least 100x faster than Ruby. There must be some
        # allocations we're  missing.
        puts "Difference on long strings: #{ruby_timing / c_timing}"
        expect(c_timing * 30).to be < ruby_timing
      end
    end
  end
end
