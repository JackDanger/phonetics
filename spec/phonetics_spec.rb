require_relative '../lib/phonetics'

RSpec.describe Phonetics do
  describe Phonetics::Vowels do
    describe '.distance' do
      subject(:distance) { described_class.distance(phoneme1, phoneme2) }
      let(:phoneme1) { 'i' }
      let(:phoneme2) { 'ɔ' }

      it 'is the hypotenuse between the two formant sets' do
        expect(distance).to be_within(0.001).of(0.7715)
      end
    end

    context 'comparing front vowels to backvowels' do
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

  describe '.distance' do
    subject(:distance) { described_class.distance(phoneme1, phoneme2) }

    context 'for similar consonants' do
      let(:phoneme1) { 'p' }
      let(:phoneme2) { 'b' }

      it { expect(distance).to be_within(0.001).of(0.1) }
    end

    context 'for dissimilar consonants' do
      let(:phoneme1) { 'p' }
      let(:phoneme2) { 'g' }

      it { expect(distance).to be_within(0.001).of(0.469) }
    end

    context 'for a vowel and a consonant' do
      let(:phoneme1) { 'i' }
      let(:phoneme2) { 't' }

      it { expect(distance).to eq(1) }
    end

    context 'for any pair of phonemes' do
      it 'is between 0 and 1 (inclusively)' do
        Phonetics.phonemes.permutation(2).each do |pair|
          distance = described_class.distance(*pair)
          raise "too high: #{pair.inspect} -> #{distance}" if distance > 1.0
          raise "too low: #{pair.inspect} -> #{distance}" if distance < 0.0
          expect(distance <= 1.0).to be_truthy
          expect(distance >= 0.0).to be_truthy
        end
      end
    end
  end

  describe Phonetics::String do
    describe '#each_phoneme' do
      subject(:each_phoneme) { described_class.new("wə t 9 ɛvɝ").each_phoneme }

      it 'returns an enumerator' do
        expect(each_phoneme).to be_an_instance_of(Enumerator)
      end

      it 'return valid phonemes, omitting any other characters' do
        expect(each_phoneme.to_a).to eq(["w", "ə", "t", "ɛ", "v", "ɝ"])
      end
    end
  end
end
