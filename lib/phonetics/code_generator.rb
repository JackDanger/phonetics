require_relative '../phonetics'
require 'json'

module Phonetics
  class CodeGenerator

    attr_reader :writer

    def initialize(writer = STDOUT)
      @writer = writer
    end

    # This will print a C code file with a function that implements a multil-level C
    # switch like the following:
    #
    #    switch (a)
    #      case 109: // only byte of "m"
    #        switch (b) {
    #          case 201: // first byte of "ɲ̊"
    #            switch (c) {
    #              case 178: // second byte of "ɲ̊"
    #                switch (d) {
    #                  case 204: // third byte of "ɲ̊"
    #                    switch (e) {
    #                      case 138: // fourth (and final) byte of "ɲ̊"
    #                        return (float) 0.4230;
    #                        break;
    #                    }
    #                }
    #            }
    #        }
    #    }
    #
    #  the distance of ("m", "ɲ̊") is therefore 0.4230
    #
    def generate_phonetic_cost_c_code
      # We turn each phoneme into an array of bytes (unicode codepoints encoded
      # via UTF-8).
      integer_distance_map = distance_map.reduce({}) do |acc_a, (a, distances)|
        acc_a.update [a, grapheme_as_utf_8_long(a)] => (distances.reduce({}) do |acc_b, (b, distance)|
          acc_b.update [b, grapheme_as_utf_8_long(b)] => distance
        end)
      end

      # Then we print out C code full of switches

      write(<<-HEADER.gsub(/^ {4}/, ''))
      float phonetic_cost(int a, int b) {
        // This is compiled from Ruby, using `String#unpack("U")` on each character
        // to retrieve the UTF-8 codepoint as a C long value.
        if (a == b) { return 0.0; };
      HEADER
      write '  switch (a) {'
      integer_distance_map.each do |(a, a_i), distances|
        write "    case #{a_i}: // #{a}"
        write '      switch (b) {'
        distances.each do |(b, b_i), distance|
          write "        case #{b_i}: // #{a}->#{b}"
          write "          return (float) #{distance};"
          write '          break;'
        end
        write '      }'
      end
      write '  }'
      write '  return 1.0;'
      write '}'

      flush
    end

    # There's no simple way to break a string of IPA characters into phonemes.
    # We do it by generating a function that, given a string of IPA characters,
    # the starting index in that string, and the length of the string, returns
    # the length of the next phoneme, or zero if none is found.
    #
    # Pseudocode:
    #   - return 0 if length - index == 0
    #   - switch on first byte, matching on possible first bytes of phonemes
    #     within the selected case statement:
    #     - return 1 if length - index == 1
    #     - switch on second byte, matching on possible second bytes of phonemes
    #       within the selected case statement:
    #       - return 2 if length - index == 1
    #       ... 
    #       - default case: return 2 iff a phoneme terminates here
    #     - default case: return 1 iff a phoneme terminates here
    #   - return 0
    #
    def generate_next_phoneme_length_c_code
      write(<<-HEADER.gsub(/^ {6}/, ''))
      int next_phoneme_length(int *string, int cursor, int length) {
        // This is compiled from Ruby, in #{__FILE__}:#{__LINE__}

        int max_length;
        max_length = length - cursor;

      HEADER

      next_phoneme_switch(phoneme_byte_trie, 0)

      # If we fell through all the cases, return 0
      write '  return 0;'
      write '}'

      flush
    end

    private

    # Recursively build switch statements for the body of next_phoneme_length
    def next_phoneme_switch(trie, depth)
      # switch (string[cursor + depth]) {
      #   case N: // for N in subtrie.keys
      #     // if a case statement matches the current byte AND there's chance
      #     // that a longer string might match, recurse.
      #     if (max_length >= depth) {
      #       // recurse
      #     }
      #     break;
      #   // if there's a :source key here then a phoneme terminates at this
      #   // point and this depth is a valid return value.
      #   default:
      #     return depth;
      #     break;
      # }
      indent depth, "switch(string[cursor + #{depth}]) {"
      write ''
      trie.each do |key, subtrie|
        next if key == :source
        next if subtrie.empty?

        indent depth, "  case #{key}:"

        # Add a comment to help understand the dataset
        if subtrie[:source]
          phoneme = subtrie[:source]
          indent depth, "     // Phoneme: #{phoneme.inspect}, bytes: #{phoneme.bytes.inspect}"
          if Phonetics::Consonants.features.key?(phoneme)
            indent depth, "     // consonant features: #{Phonetics::Consonants.features[phoneme].to_json}"
          else
            indent depth, "     // vowel features: #{Phonetics::Vowels::FormantFrequencies[phoneme].to_json}"
          end
        end

        if subtrie.keys == [:source]
          indent depth, "    return #{depth+1};"
        else
          indent depth, "    if (max_length > #{depth + 1}) {"
          next_phoneme_switch(subtrie, depth + 1)
          indent depth, "    }"
        end

        indent depth, "    break;"
      end

      if trie.key?(:source)
        indent depth, "  default:"
        indent depth, "    return #{depth};"
      end
      indent depth, "}"
    end

    # Turn the bytes of all phonemes into a lookup trie where a sequence of
    # bytes can find a phoneme in linear time.
    def phoneme_byte_trie
      Phonetics.phonemes.reduce({}) do |trie, phoneme|
        phoneme.bytes.each_with_index.reduce(trie) do |subtrie, (byte, idx)|
          subtrie[byte] ||= {}

          # If we've reached the end of the byte string
          if phoneme.bytes.length - 1 == idx
            # Check if this is a duplicate lookup path. If there's a collision
            # then this whole approach makes no sense.
            if subtrie[byte].key?(:source)
              source = subtrie[byte][:source]
              raise "Duplicate byte sequence on #{phoneme.inspect} & #{source.inspect} (#{phoneme.bytes.inspect})"
            else
              subtrie[byte][:source] = phoneme
            end
          end
          subtrie[byte]
        end
        trie
      end
    end

    def indent(depth, line)
      write "  #{'      ' * depth}#{line}"
    end

    def write(line)
      writer.puts line
    end

    def flush
      writer.flush
    end
  end
end