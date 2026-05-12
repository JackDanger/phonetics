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

  describe 'empirical overlay' do
    it 'applies the th-stopping discount to /θ/-/t/ and /ð/-/d/' do
      expect(described_class.sub_cost('θ', 't')).to be < Phonetics.distance('θ', 't')
      expect(described_class.sub_cost('ð', 'd')).to be < Phonetics.distance('ð', 'd')
    end

    it 'treats American /t/-flap as near-identical to /d/' do
      # 'butter' ≈ 'budder' ≈ 'buɾer' in American English.
      expect(described_class.sub_cost('t', 'ɾ')).to be < 0.15
      expect(described_class.sub_cost('d', 'ɾ')).to be < 0.10
    end

    it 'does not leak overlay values into Phonetics.distance' do
      # Strict acoustic distance must stay honest about the dental→alveolar
      # manner change even when the perceptual layer discounts it.
      expect(Phonetics.distance('θ', 't')).to be > 0.20
    end

    it 'is symmetric' do
      [%w[θ t], %w[t ɾ], %w[l ɹ], %w[p f]].each do |a, b|
        expect(described_class.sub_cost(a, b)).to be_within(1e-9).of(described_class.sub_cost(b, a))
      end
    end
  end

  describe 'lateral airflow feature' do
    it 'distinguishes /l/ from /ɹ/' do
      # Without LATERAL_PENALTY, both are alveolar approximants with manner
      # rank 1.0 and the distance was tied at exactly 0.
      expect(Phonetics.distance('l', 'ɹ')).to be > 0.0
    end

    it 'penalises a lateral/non-lateral mismatch on otherwise-similar consonants' do
      # /ɬ/ and /s/ share alveolar place and voiceless voicing; they differ
      # only in lateral airflow + sibilance. /ɮ/ vs /z/ is the voiced
      # counterpart. With LATERAL_PENALTY each gets a clear non-zero cost.
      expect(Phonetics::Consonants.distance('ɬ', 's')).to be > Phonetics::Consonants::LATERAL_PENALTY * 0.9
      expect(Phonetics::Consonants.distance('ɮ', 'z')).to be > Phonetics::Consonants::LATERAL_PENALTY * 0.9
    end
  end

  describe 'word-boundary support' do
    it 'tokenises spaces into the boundary token only when boundaries: true' do
      s = Phonetics::String.new('it is just')
      expect(s.each_phoneme.to_a).to eq(%w[i t i s j u s t])
      expect(s.each_phoneme(boundaries: true).to_a).to eq(['i', 't', '#', 'i', 's', '#', 'j', 'u', 's', 't'])
    end

    it 'gives near-zero cost to repositioning a word boundary' do
      # Same phonemes, different word-boundary placement: the difference
      # is entirely re-syllabification.
      a = 'ɪts dʒʌst'   # "it's just"
      b = 'ɪt sdʒʌst'    # "it sjust" — same phonemes, boundary moved
      expect(d(a, b)).to be_within(2 * described_class::BOUNDARY_INDEL_COST).of(0)
    end

    it 'improves discrimination on a Mad Gab pair when boundaries are present' do
      target_b = 'ɪts dʒʌst ə stupɪd geɪm'
      clue_b   = 'hɪts dʒʌstɪs dup hɪd keɪm'
      decoy_b  = 'jɔr mʌðɝ wɛrz sneɪkɝz'
      expect(d(target_b, clue_b)).to be < d(target_b, decoy_b)
    end
  end

  describe 'C extension parity' do
    let(:samples) do
      [
        %w[kæt kæt],
        %w[kæt kʌt],
        %w[ɪtsdʒʌstəstupɪdgeɪm hɪtsdʒʌstɪsduphɪdkeɪm],
        %w[æpəlpaɪ eɪppʊlpaɪ],
        %w[nidəkɔfi nidɑkhɔffi],
        ['ɪts dʒʌst ə stupɪd geɪm', 'hɪts dʒʌstɪs dup hɪd keɪm'], # spaced
        ['mæstɝ beɪkɝ', 'mæs stɝ beɪk hɝ'],
      ]
    end

    it 'is available alongside the Ruby reference' do
      expect(defined?(::PhoneticsConfusionCBinding)).to be_truthy
    end

    it 'agrees with the Ruby reference on every sample' do
      samples.each do |a, b|
        c = Phonetics::CConfusion.distance(a, b)
        r = Phonetics::RubyConfusion.new(a, b).distance
        expect(c).to be_within(0.005).of(r),
                     "C=#{c.inspect}, Ruby=#{r.inspect} for (#{a.inspect}, #{b.inspect})"
      end
    end

    it 'is the path .distance picks by default when the bundle is loaded' do
      # Smoke check: calling Confusion.distance should be fast enough to
      # suggest it's hitting C, not Ruby. We don't pin a number — only
      # check the contract that .distance returns the same value the C
      # wrapper does.
      a, b = 'ɪts dʒʌst ə stupɪd geɪm', 'hɪts dʒʌstɪs dup hɪd keɪm'
      expect(described_class.distance(a, b)).to be_within(1e-6).of(Phonetics::CConfusion.distance(a, b))
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
