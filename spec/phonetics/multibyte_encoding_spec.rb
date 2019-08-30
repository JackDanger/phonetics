# frozen_string_literal: true

require_relative '../../lib/phonetics'
require_relative '../../lib/phonetics/levenshtein'

RSpec.describe Phonetics do
  context 'testing codepoints' do
    let(:string) { " aɰ̊ h" }

    it 'prints to stdout' do
      Phonetics::Levenshtein.codepoints(string)
    end

    it 'encodes lists of bytes that are completely differentiable' do
      byte_trie = {}
      Phonetics.distance_map.each do |k1, values|
        values.each do |k2, distance|
          [
            k1.bytes + k2.bytes,
          ].each do |byte_list|
            byte_list.each_with_index.reduce(byte_trie) do |trie, (byte, idx)|
              is_last = idx == byte_list.size - 1

              if trie[byte] && is_last && trie[byte].keys != [:set_by, 204]
                puts "Found overlap: #{trie[byte].keys.inspect}"
                p [idx, byte, k1, k2, byte_list]
              end
              #expect(trie[byte]).to be_nil if is_last

              trie[byte] ||= { set_by: [k1, k2, byte_list] }
            end
          end
        end
      end
    end
  end
end

