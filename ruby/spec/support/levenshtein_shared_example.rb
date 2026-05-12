# frozen_string_literal: true

# These examples exercise both the pure-Ruby and the C-extension Levenshtein
# implementations through identical assertions. They're framed as relative
# expectations (one distance is bigger/smaller than another) rather than
# pinned numeric values, so the suite survives weight-tuning changes.
RSpec.shared_examples 'calculates levenshtein distance' do
  describe '.distance' do
    subject(:distance) { described_class.distance(phoneme1, phoneme2, verbose) }

    let(:verbose) { false }

    context 'for identical strings' do
      let(:phoneme1) { 'kæt' }
      let(:phoneme2) { 'kæt' }

      it 'is exactly zero' do
        expect(distance).to eq(0)
      end
    end

    context 'for a one-phoneme deletion at the head' do
      let(:phoneme1) { 'dɪsug' }
      let(:phoneme2) { 'ɪsug' }

      it 'costs approximately one indel' do
        expect(distance).to be_within(0.05).of(described_class::INDEL_COST)
      end
    end

    context 'for the README example /bæd/ vs /ben/ (and exercising verbosity)' do
      let(:phoneme1) { 'bæd' }
      let(:phoneme2) { 'ben' }

      let(:verbose) { true }

      it 'is the sum of /æ/↔/e/ and /d/↔/n/ phoneme distances' do
        expected = Phonetics.distance('æ', 'e') + Phonetics.distance('d', 'n')
        expect(distance).to be_within(0.01).of(expected)
      end

      it 'is strictly less than two full substitutions' do
        expect(distance).to be < 2 * described_class::INDEL_COST
      end
    end

    context 'for four position-aligned substitutions' do
      let(:phoneme1) { 'izok' }
      let(:phoneme2) { 'ɪsug' }

      it 'is the sum of paired phoneme distances' do
        expected = phoneme1.chars.zip(phoneme2.chars).sum { |a, b| Phonetics.distance(a, b) }
        expect(distance).to be_within(0.05).of(expected)
      end

      it 'is strictly less than the indel cost of replacing one string' do
        expect(distance).to be < phoneme2.length * described_class::INDEL_COST
      end
    end

    # We don't expect repeated identical sounds in most good transcriptions, but
    # it can happen when a program naively concatenates the transcriptions of
    # multiple words. Two extra phonemes should still cost less than two indels
    # because one of each pair matches for free.
    context 'when identical sounds repeat' do
      let(:phoneme1) { 'ɪɪsuug' }
      let(:phoneme2) { 'ɪsug' }

      it 'is less than the absolute length difference' do
        expect(distance).to be <= (phoneme1.length - phoneme2.length) * described_class::INDEL_COST
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

      it 'is the length of the non-empty string times the indel cost' do
        # Phoneme count of the IPA string (a few are multi-codepoint).
        expected = Phonetics::String.new(phoneme1).each_phoneme.to_a.size *
                   described_class::INDEL_COST
        expect(distance).to be_within(0.01).of(expected)
      end
    end

    context 'for very different sounds' do
      let(:phoneme1) { 'mɔop' }
      let(:phoneme2) { 'sinkœ' }

      it 'approaches but does not exceed the orthographic Levenshtein edit distance' do
        edit_distance = [phoneme1.length, phoneme2.length].max
        expect(distance).to be < edit_distance * described_class::INDEL_COST + 0.01
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
