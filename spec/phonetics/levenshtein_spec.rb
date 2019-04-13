require_relative '../../lib/phonetics/levenshtein'

RSpec.describe Phonetics::Levenshtein do
  describe '#distance' do
    subject(:distance) { described_class.new(phoneme1, phoneme2).distance }

    context 'for identical sounds with one edit' do
      let(:phoneme1) { 'dɪsug' }
      let(:phoneme2) { 'ɪsug' }

      it 'is less than the edit distance' do
        expect(distance).to be_within(0.01).of(1)
      end
    end

    context 'for many different but similar sounds' do
      let(:phoneme1) { 'izok' }
      let(:phoneme2) { 'ɪsug' }

      it 'is less than the edit distance' do
        expect(distance).to be_within(0.01).of(1.212)
      end
    end

    # We don't expect repeated identical sounds in most good transcriptions but
    # this can happen when a program naively concatenates the transcriptions of
    # multiple words. Even in the case of the sounds truly being repeated lets
    # record the edit distance as nearly zero
    pending 'when identical sounds repeat' do
      let(:phoneme1) { 'dɪɪɪsug' }
      let(:phoneme2) { 'ɪsug' }

      it 'is less than the edit distance' do
        expect(distance).to be_within(0.01).of(1.01)
      end
    end

    context 'for two blank strings' do
      let(:phoneme1) { '' }
      let(:phoneme2) { '' }

      it 'is zero' do
        expect(distance).to eq(0)
      end
    end

    context 'for one blank strings' do
      let(:phoneme1) { 'length' }
      let(:phoneme2) { '' }

      it 'is the length of the other string' do
        expect(distance).to eq(6)
      end
    end

    context 'for very different sounds' do
      let(:phoneme1) { 'mɔop' }
      let(:phoneme2) { 'sinkœ' }

      it 'approaches the orthographic Levenshtein edit distance' do
        expect(distance).to be_within(0.2).of(4)
      end
    end

    context 'when the inputs are not valid phonemes' do
      let(:phoneme1) { '12345' }
      let(:phoneme2) { '67890' }

      it 'is exactly the orthographic Levenshtein edit distance' do
        expect(distance).to be_within(0.01).of(5)
      end
    end
  end
end
