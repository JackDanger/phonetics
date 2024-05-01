# frozen_string_literal: true

RSpec.shared_examples 'calculates levenshtein distance' do
  describe '.distance' do
    subject(:distance) { described_class.distance(phoneme1, phoneme2, verbose) }

    let(:verbose) { false }

    context 'for identical sounds with one edit' do
      let(:phoneme1) { 'dɪsug' }
      let(:phoneme2) { 'ɪsug' }

      it 'is about the edit distance' do
        expect(distance).to be_within(0.01).of(1)
      end
    end

    context 'for the README (and testing verbosity)' do
      let(:phoneme1) { 'bæd' }
      let(:phoneme2) { 'ben' }

      let(:verbose) { true }

      it 'is less than the edit distance' do
        expect(distance).to be_within(0.01).of(0.55)
      end
    end

    context 'for many different but similar sounds' do
      let(:phoneme1) { 'izok' }
      let(:phoneme2) { 'ɪsug' }

      it 'is less than the edit distance' do
        expect(distance).to be_within(0.01).of(0.678)
      end
    end

    # We don't expect repeated identical sounds in most good transcriptions but
    # this can happen when a program naively concatenates the transcriptions of
    # multiple words. Even in the case of the sounds truly being repeated lets
    # record the edit distance as nearly zero
    context 'when identical sounds repeat' do
      let(:phoneme1) { 'ɪɪsuug' }
      let(:phoneme2) { 'ɪsug' }

      it 'is less than the edit distance' do
        expect(distance).to be < (phoneme1.length - phoneme2.length)
      end
    end

    context 'for two blank strings' do
      let(:phoneme1) { '' }
      let(:phoneme2) { '' }

      it 'is zero' do
        expect(distance).to eq(0)
      end
    end

    context 'when one string is blank' do
      let(:phoneme1) { 'kuɹzlɑɪt' }
      let(:phoneme2) { '' }

      it 'is the sequential distances of sounds in the other string' do
        sequential_total = phoneme1.chars.each_cons(2).reduce(0) do |total, pair|
          total + Phonetics.distance(*pair)
        end
        expect(distance).to be_within(0.01).of(sequential_total)
      end
    end

    context 'for very different sounds' do
      let(:phoneme1) { 'mɔop' }
      let(:phoneme2) { 'sinkœ' }

      it 'approaches the orthographic Levenshtein edit distance' do
        expect(distance).to be_within(0.2).of(3.35)
      end
    end

    context 'when the inputs are not valid phonemes' do
      let(:phoneme1) { '12345' }
      let(:phoneme2) { '67890' }

      it 'skips over them (i.e. operates on zero-length strings)' do
        expect(distance).to be_within(0.001).of(0)
      end
    end
  end
end
