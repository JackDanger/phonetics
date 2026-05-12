# frozen_string_literal: true

require_relative '../../lib/phonetics/confusion'
require_relative '../../lib/phonetics/ruby_levenshtein'

# Invariants for the listener-confusion metric. These are the properties that
# any sane perceptual distance has to satisfy regardless of weight tuning:
# identity, symmetry, monotonicity, weak-phoneme cheapness, and "the same
# phrase against itself is zero".
RSpec.describe Phonetics::Confusion do
  def d(a, b)
    described_class.distance(a, b)
  end

  describe '.distance' do
    it 'is zero for identical phrases' do
      %w[kæt stupɪd ɪtsdʒʌstəstupɪdgeɪm].each do |phrase|
        expect(d(phrase, phrase)).to eq(0)
      end
    end

    it 'is symmetric' do
      pairs = [%w[kæt kʌt], %w[stupɪd dupɪd], %w[hɪt ɪt], %w[nidəkɔfi nidɑkhɔffi]]
      pairs.each { |a, b| expect(d(a, b)).to be_within(1e-9).of(d(b, a)) }
    end

    it 'is non-negative' do
      [%w[kæt dɔg], %w[stupɪd dʒʌmpz], %w[hɪtsdʒʌstɪs ɪtsdʒʌst]].each do |a, b|
        expect(d(a, b)).to be >= 0.0
      end
    end

    it 'is below strict Levenshtein on Mad-Gab-style pairs' do
      # The whole point of the confusion metric: same-target / different-
      # surface-form pairs should score cheaper than strict edit distance.
      target, clue = 'ɪtsdʒʌstəstupɪdgeɪm', 'hɪtsdʒʌstɪsduphɪdkeɪm'
      expect(d(target, clue)).to be < Phonetics::RubyLevenshtein.distance(target, clue)
    end

    it 'charges less for a contiguous multi-phoneme insertion than the strict metric does' do
      # `stupɪd` vs `stupɪdli` adds 2 phonemes at the tail. Strict charges
      # 2 indels (= 2.0). Confusion should charge GAP_OPEN + GAP_EXTEND.
      a, b = 'stupɪd', 'stupɪdli'
      expected = described_class::GAP_OPEN + described_class::GAP_EXTEND
      expect(d(a, b)).to be_within(0.01).of(expected)
    end

    it 'discounts indels of weak phonemes (ə, h, ʔ, ɦ)' do
      base = 'stupɪd'
      with_h = 'hstupɪd'           # insert /h/ at head
      with_schwa = 'stəupɪd'        # insert /ə/ in middle (gives schwa)
      expect(d(base, with_h)).to be_within(0.01).of(described_class::WEAK_INDEL_COST)
      expect(d(base, with_schwa)).to be_within(0.01).of(described_class::WEAK_INDEL_COST)
    end

    it 'gives an unrelated phrase a clearly higher distance than a Mad Gab clue' do
      target = 'ɪtsdʒʌstəstupɪdgeɪm'
      clue   = 'hɪtsdʒʌstɪsduphɪdkeɪm'
      decoy  = 'jɔrmʌðɝwɛrzsneɪkɝz'
      expect(d(target, decoy)).to be > 5 * d(target, clue)
    end
  end

  describe '.similarity' do
    it 'returns 1.0 for identical phrases' do
      expect(described_class.similarity('kæt', 'kæt')).to eq(1.0)
      expect(described_class.similarity('', '')).to eq(1.0)
    end

    it 'returns a value in [0, 1]' do
      pairs = [
        %w[kæt dɔg],
        %w[stupɪdgeɪm dʒʌmpɪnsplæʃ],
        %w[ɪtsdʒʌstəstupɪdgeɪm hɪtsdʒʌstɪsduphɪdkeɪm],
      ]
      pairs.each do |a, b|
        s = described_class.similarity(a, b)
        expect(s).to be_between(0.0, 1.0)
      end
    end

    it 'puts the Mad Gab clue above 0.9 similarity' do
      target = 'ɪtsdʒʌstəstupɪdgeɪm'
      clue   = 'hɪtsdʒʌstɪsduphɪdkeɪm'
      expect(described_class.similarity(target, clue)).to be > 0.9
    end

    it 'ranks the clue at least 0.2 above an unrelated decoy' do
      target = 'ɪtsdʒʌstəstupɪdgeɪm'
      clue   = 'hɪtsdʒʌstɪsduphɪdkeɪm'
      decoy  = 'jɔrmʌðɝwɛrzsneɪkɝz'
      sim_clue  = described_class.similarity(target, clue)
      sim_decoy = described_class.similarity(target, decoy)
      expect(sim_clue - sim_decoy).to be >= 0.2
    end
  end

  describe 'two-tier API contract' do
    it "exposes Phonetics::Levenshtein as the strict per-phoneme edit distance" do
      # Strict and confusion should diverge meaningfully on length-changing
      # alignments; if they ever coincide on a real Mad Gab pair the user
      # wouldn't have gained anything from the new metric.
      target = 'nidəkɔfi'
      clue   = 'nidɑkhɔffi'
      strict = Phonetics::RubyLevenshtein.distance(target, clue)
      perceptual = described_class.distance(target, clue)
      expect(perceptual).to be < strict
    end
  end
end
