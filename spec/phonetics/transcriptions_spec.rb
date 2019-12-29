require 'phonetics/transcriptions'

RSpec.describe Phonetics::Transcriptions do

  def max_rarity_in_trie(trie)
    trie.reduce(0) do |max_so_far, (key, subtrie)|
      max = if key == :terminal
              subtrie.max_by do |word_data|
                word_data[:rarity]
              end[:rarity]
            elsif key.is_a?(String)
              max_rarity_in_trie(subtrie)
            else
              0
            end
      [max, max_so_far].max
    end
  end

  describe '.trie' do
    subject(:trie) { described_class.trie(max_rarity) }

    context 'with no max_rarity' do
      let(:max_rarity) { }

      it 'returns all transcriptions, even those with rarity unset' do
        rarity_under_100_000 = described_class.trie(100_000)
        # We should get more transcriptions with a null max_rarity than we do
        # with even an improbably high one
        expect(trie.to_json.size).to be > rarity_under_100_000.to_json.size
      end
    end

    context 'with a high max_rarity' do
      let(:max_rarity) { 120_000 }

      it 'returns all transcriptions with rarity set' do
        # No words have a rarity higher than ~65_000
        expect(max_rarity_in_trie(trie)).to be_between(60_000, 70_000)
      end
    end

    context 'with a low max_rarity' do
      let(:max_rarity) { 100 }

      it 'returns just the top 100 words' do
        expect(max_rarity_in_trie(trie)).to be_between(90, 100)
      end
    end
  end
end
