# frozen_string_literal: true

require 'phonetics'

# Public API specs for the Rust-backed Phonetics gem.
#
# These tests exercise only what's reachable from `require 'phonetics'`.
# Implementation-internal data (vowel formant tables, consonant
# feature parsing, the empirical overlay) is no longer in Ruby — it's
# all in the Rust core crate where its own unit tests pin reference
# values to f64 precision. Here we just verify the Ruby-side surface.
RSpec.describe Phonetics do
  describe '.distance (per-phoneme acoustic)' do
    it 'is zero for identical phonemes' do
      %w[p b t i ɑ æ tʃ aɪ ɝ].each do |p|
        expect(described_class.distance(p, p)).to eq(0)
      end
    end

    it 'is the voicing penalty for /p/-/b/' do
      expect(described_class.distance('p', 'b')).to be_within(1e-9).of(0.15)
    end

    it 'distinguishes /l/ from /ɹ/ (lateral feature)' do
      expect(described_class.distance('l', 'ɹ')).to be > 0.0
    end

    it 'distinguishes /ə/ from rhotic /ɝ/' do
      expect(described_class.distance('ə', 'ɝ')).to be > 0.0
    end

    it 'puts approximants near their corresponding vowels' do
      expect(described_class.distance('j', 'i')).to be < described_class.distance('t', 'i')
      expect(described_class.distance('w', 'u')).to be < described_class.distance('t', 'u')
      expect(described_class.distance('ɹ', 'ɝ')).to be < described_class.distance('t', 'ɝ')
    end

    it 'stays acoustically honest about cot/caught (no WCE overlay here)' do
      # Strict acoustic distance: /ɑ/ vs /ɔ/ have meaningful formant
      # separation. The perceptual layer is what merges them.
      expect(described_class.distance('ɑ', 'ɔ')).to be > 0.15
    end
  end

  describe '.levenshtein (strict edit distance)' do
    it 'is zero for identical strings' do
      expect(described_class.levenshtein('kæt', 'kæt')).to eq(0)
    end

    it 'costs approximately one indel for a single-phoneme deletion' do
      expect(described_class.levenshtein('dɪsug', 'ɪsug')).to be_within(0.05).of(1.0)
    end

    it 'symmetric across realistic pairs' do
      [%w[kæt kʌt], %w[stupɪd dupɪd], %w[hɪt ɪt]].each do |a, b|
        expect(described_class.levenshtein(a, b)).to be_within(1e-9).of(described_class.levenshtein(b, a))
      end
    end
  end

  describe '.confusion (listener perception)' do
    it 'is zero for identical strings' do
      expect(described_class.confusion('kæt', 'kæt')).to eq(0)
    end

    it 'is cheaper than strict Levenshtein on a Mad Gab pair' do
      target = 'ɪtsdʒʌstəstupɪdgeɪm'
      clue   = 'hɪtsdʒʌstɪsduphɪdkeɪm'
      expect(described_class.confusion(target, clue)).to be < described_class.levenshtein(target, clue)
    end

    it 'ranks the Mad Gab clue ≥5× closer than an unrelated decoy' do
      target = 'ɪtsdʒʌstəstupɪdgeɪm'
      clue   = 'hɪtsdʒʌstɪsduphɪdkeɪm'
      decoy  = 'jɔrmʌðɝwɛrzsneɪkɝz'
      expect(described_class.confusion(target, decoy)).to be > 5 * described_class.confusion(target, clue)
    end

    it 'charges near-zero for a moved word boundary' do
      expect(described_class.confusion('ɪts dʒʌst', 'ɪt sdʒʌst')).to be < 0.05
    end
  end

  describe '.similarity' do
    it 'is 1.0 for identical strings' do
      expect(described_class.similarity('kæt', 'kæt')).to eq(1.0)
    end

    it 'separates clue from decoy by ≥0.2' do
      target = 'ɪtsdʒʌstəstupɪdgeɪm'
      clue   = 'hɪtsdʒʌstɪsduphɪdkeɪm'
      decoy  = 'jɔrmʌðɝwɛrzsneɪkɝz'
      delta = described_class.similarity(target, clue) - described_class.similarity(target, decoy)
      expect(delta).to be >= 0.2
    end
  end

  describe '.sub_cost (perceptual per-phoneme, with overlay)' do
    it 'reflects the t-flapping discount' do
      expect(described_class.sub_cost('t', 'ɾ')).to be < 0.15
    end

    it 'reflects the cot/caught merger (WCE overlay)' do
      expect(described_class.sub_cost('ɑ', 'ɔ')).to be < 0.10
    end

    it 'is symmetric' do
      [%w[θ t], %w[t ɾ], %w[l ɹ], %w[p f]].each do |a, b|
        expect(described_class.sub_cost(a, b)).to be_within(1e-9).of(described_class.sub_cost(b, a))
      end
    end
  end

  describe '.tokenize' do
    it 'splits an IPA string into phonemes' do
      expect(described_class.tokenize('kæt')).to eq(%w[k æ t])
    end

    it 'recognises diphthongs as atomic phonemes' do
      expect(described_class.tokenize('kɑɪt')).to eq(%w[k ɑɪ t])
    end

    it 'recognises affricates as atomic phonemes' do
      expect(described_class.tokenize('dʒʌdʒ')).to eq(%w[dʒ ʌ dʒ])
    end

    it 'absorbs aspiration onto the preceding consonant' do
      expect(described_class.tokenize('pʰɪt')).to eq(%w[pʰ ɪ t])
    end

    it 'drops whitespace by default' do
      expect(described_class.tokenize('kæt dɔg')).to eq(%w[k æ t d ɔ g])
    end

    it 'emits # boundary tokens with boundaries: true' do
      expect(described_class.tokenize('kæt dɔg', boundaries: true)).to eq(
        ['k', 'æ', 't', '#', 'd', 'ɔ', 'g'],
      )
    end
  end

  describe '::String (legacy delegator)' do
    it 'enumerates phonemes via each_phoneme' do
      tokens = Phonetics::String.new('wətɛvɝ').each_phoneme.to_a
      expect(tokens).to eq(%w[w ə t ɛ v ɝ])
    end

    it 'honours the boundaries: kwarg' do
      tokens = Phonetics::String.new('ɪt s').each_phoneme(boundaries: true).to_a
      expect(tokens).to eq(['ɪ', 't', '#', 's'])
    end
  end

  describe 'namespaced compat shims' do
    it 'Phonetics::Levenshtein.distance routes to the Rust path' do
      expect(Phonetics::Levenshtein.distance('kæt', 'kʌt')).to be_within(1e-9).of(
        Phonetics.levenshtein('kæt', 'kʌt'),
      )
    end

    it 'Phonetics::Confusion.distance routes to the Rust path' do
      expect(Phonetics::Confusion.distance('kæt', 'kʌt')).to be_within(1e-9).of(
        Phonetics.confusion('kæt', 'kʌt'),
      )
    end

    it 'Phonetics::Confusion.similarity and .sub_cost forward correctly' do
      expect(Phonetics::Confusion.similarity('kæt', 'kʌt')).to eq(Phonetics.similarity('kæt', 'kʌt'))
      expect(Phonetics::Confusion.sub_cost('t', 'ɾ')).to eq(Phonetics.sub_cost('t', 'ɾ'))
    end
  end
end
