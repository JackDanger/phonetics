# frozen_string_literal: true

require_relative '../lib/phonetics'

# These specs assert *relative* phonetic relationships, not pinned numeric
# values. Pinning numbers couples the test suite to the current weight tuning;
# the cross-pair orderings below are what actually has to hold for the metric
# to be useful as Levenshtein input.
RSpec.describe Phonetics do
  describe Phonetics::Vowels do
    describe '.distance' do
      it 'is zero for a vowel against itself' do
        Phonetics::Vowels::FormantFrequencies.each_key do |v|
          expect(described_class.distance(v, v)).to eq(0)
        end
      end

      it 'is symmetric' do
        keys = Phonetics::Vowels::FormantFrequencies.keys
        keys.combination(2).each do |a, b|
          expect(described_class.distance(a, b)).to be_within(1e-9).of(described_class.distance(b, a))
        end
      end

      it 'is bounded in [0, 1]' do
        keys = Phonetics::Vowels::FormantFrequencies.keys
        keys.combination(2).each do |a, b|
          expect(described_class.distance(a, b)).to be_between(0.0, 1.0)
        end
      end

      it 'distinguishes /ə/ from rhotic /ɝ/' do
        expect(described_class.distance('ə', 'ɝ')).to be > 0.1
      end

      it 'distinguishes rounded /y/ from unrounded /i/ despite near-identical formants' do
        expect(described_class.distance('i', 'y')).to be > 0.0
      end
    end

    context 'comparing front vowels to back vowels' do
      {
        'a' => { closer: 'œ', further: 'o' },
        'i' => { closer: 'ɪ', further: 'œ' },
        'ɪ' => { closer: 'œ', further: 'o' },
        'o' => { closer: 'u', further: 'œ' },
        'u' => { closer: 'o', further: 'œ' },
        'ʊ' => { closer: 'u', further: 'i' },
        'ɔ' => { closer: 'u', further: 'i' },
      }.each do |phoneme, comp|
        it "recognizes #{phoneme.inspect} is closer to #{comp[:closer].inspect} than to #{comp[:further].inspect}" do
          expect(
            described_class.distance(phoneme, comp[:closer]) <
            described_class.distance(phoneme, comp[:further])
          ).to be_truthy
        end
      end
    end
  end

  describe Phonetics::Consonants do
    describe '.distance' do
      it 'is zero for a consonant against itself' do
        Phonetics::Consonants.features.each_key do |c|
          expect(described_class.distance(c, c)).to eq(0)
        end
      end

      it 'is symmetric' do
        Phonetics::Consonants.phonemes.combination(2).each do |a, b|
          expect(described_class.distance(a, b)).to be_within(1e-9).of(described_class.distance(b, a))
        end
      end

      it 'is bounded in [0, 1]' do
        Phonetics::Consonants.phonemes.combination(2).each do |a, b|
          expect(described_class.distance(a, b)).to be_between(0.0, 1.0)
        end
      end

      it 'puts homorganic voicing pairs at the cheap end' do
        expect(described_class.distance('p', 'b')).to be < described_class.distance('p', 'k')
        expect(described_class.distance('t', 'd')).to be < described_class.distance('t', 'g')
      end

      it 'puts same-manner place neighbours closer than cross-manner same-place' do
        expect(described_class.distance('s', 'ʃ')).to be < described_class.distance('s', 't')
        expect(described_class.distance('m', 'n')).to be < described_class.distance('m', 'p')
      end

      it 'penalises cross-manner pairs more than voicing flips' do
        expect(described_class.distance('s', 'z')).to be < described_class.distance('s', 't')
      end
    end
  end

  describe '.distance' do
    subject(:distance) { described_class.distance(phoneme1, phoneme2) }

    context 'for identical phonemes' do
      let(:phoneme1) { 'i' }
      let(:phoneme2) { 'i' }
      it { is_expected.to eq(0) }
    end

    context 'for any pair of phonemes' do
      it 'is between 0 and 1 (inclusively)' do
        Phonetics.phonemes.permutation(2).each do |pair|
          distance = described_class.distance(*pair)
          raise "too high: #{pair.inspect} -> #{distance}" if distance > 1.0
          raise "too low: #{pair.inspect} -> #{distance}" if distance < 0.0

          expect(distance).to be_between(0.0, 1.0)
        end
      end
    end

    context 'cross-class bridge' do
      it 'puts /j/ closer to /i/ than to /t/' do
        expect(described_class.distance('j', 'i')).to be < described_class.distance('j', 't')
      end

      it 'puts /w/ closer to /u/ than to /t/' do
        expect(described_class.distance('w', 'u')).to be < described_class.distance('w', 't')
      end

      it 'puts /ɹ/ closer to /ɝ/ than to /s/' do
        expect(described_class.distance('ɹ', 'ɝ')).to be < described_class.distance('ɹ', 's')
      end

      it 'never charges the full unit cost for any phoneme pair' do
        # The Levenshtein layer reserves 1.0 for indel cost; the per-phoneme
        # metric should always sit strictly below that.
        Phonetics.phonemes.permutation(2).each do |a, b|
          expect(described_class.distance(a, b)).to be < 1.0
        end
      end
    end
  end

  describe Phonetics::String do
    describe '#each_phoneme' do
      subject(:each_phoneme) { described_class.new('wə t 9 ɛvɝ').each_phoneme }

      it 'returns an enumerator' do
        expect(each_phoneme).to be_an_instance_of(Enumerator)
      end

      it 'return valid phonemes, omitting any other characters' do
        expect(each_phoneme.to_a).to eq(%w[w ə t ɛ v ɝ])
      end
    end
  end
end
