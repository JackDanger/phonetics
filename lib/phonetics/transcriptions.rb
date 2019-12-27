# frozen_string_literal: true

require 'open-uri'
require 'json'

module Phonetics
  def self.transcription_for(phrase)
    phrase.downcase.split(' ').map { |word| Transcriptions[word] }.join
  end

  module Transcriptions
    extend self

    TranscriptionFile = File.join(__dir__, '..', 'common_ipa_transcriptions.json')
    TranscriptionsURL = 'https://jackdanger.com/common_ipa_transcriptions.json'

    SourcesByPreference = [/wiktionary/, /cmu/, /phonemicchart.com/].freeze

    def [](key)
      entry = transcriptions[key]
      return unless entry
      return unless entry['ipa']

      SourcesByPreference.each do |preferred_source|
        entry['ipa'].keys.each do |source|
          return entry['ipa'][source] if source =~ preferred_source
        end
      end
      nil
    end

    def transcriptions
      @transcriptions ||= begin
        download! unless File.exist?(TranscriptionFile)
        load_from_disk!
      end
    end

    # Lazily loaded from JSON file on disk
    def load_from_disk!
      @transcriptions = JSON.parse(File.read(Transcriptions))
    end

    def download!
      File.open(Transcriptions, 'w') { |f| f.write(URI.open(TranscriptionsURL).read) }
    end

    def trie
      # Let's turn this:
      #
      #    "century": {
      #      "rarity": 462.0,
      #      "ipa": {
      #        "cmu": "sɛntʃɝɪ",
      #        "phonemicchart.com": "sentʃərɪ",
      #        "wiktionary": "sɛntʃəɹi",
      #        "wiktionary2": "sɛntʃɹi",
      #        "wiktionary3": "sɛntʃʊɹi"
      #      },
      #      "alt_display": "CENTURY"
      #    }
      #
      # into this:
      #
      #   "s": {
      #     "e": {
      #       "n": {
      #         "t": {
      #           "ʃ": {
      #             "ʊ": {
      #               "ɹ": {
      #                 "i": {
      #                   "terminal": [Term('century')],
      #                 },
      #               },
      #             },
      #             "ə": {
      #               "r": {
      #                 "ɪ": {
      #                   "terminal": [Term('century')],
      #                 },
      #               },
      #             },
      #             "ɹ": {
      #               "i": {
      #                 "terminal": [Term('century')],
      #               },
      #             },
      #             "ɝ": {
      #               "ɪ": {
      #                 "terminal": [Term('century')],
      #               },
      #             },
      #           },
      #         },
      #       },
      #     },
      #     "ɛ": {
      #       "n": {
      #         "t": {
      #           "ʃ": {
      #             "ɝ": {
      #               "ɪ": {
      #                 "terminal": [Term('century')],
      #               },
      #             },
      #           },
      #         },
      #       },
      #     },
      #   },
      #
      @trie ||= begin
        base_trie = {}
        transcriptions.each do |key, entry|
          entry_data = {
              word: key,
            rarity: entry['rarity'],
          }
          entry.fetch('ipa', []).each do |_source, transcription|
            base_trie = construct_trie(base_trie, transcription, entry_data)
          end
        end
        base_trie.freeze
      end
    end

    def walk(ipa)
      ipa.each_char.reduce(trie) { |acc, char| acc[char] }
    end

    def transcription_for(phrase)
      phrase.downcase.split(' ').map { |word| self[word] }.join
    end

    private

    # Given an portion of an existing trie (to be modified), the remainder of a
    # char string, and an entry, walk or construct the appropriate trie nodes
    # necessary to place the entry in a leaf.
    def construct_trie(subtrie, chars_remaining, entry_data, depth = 0)
      subtrie[:depth] ||= depth
      if chars_remaining.empty?
        # Base condition met
        subtrie[:terminal] ||= []
        subtrie[:terminal] << entry_data unless subtrie[:terminal].include?(entry_data)
      else
        next_char = chars_remaining[0]
        subtrie[next_char] ||= {}
        subtrie[next_char][:path] ||= subtrie[:path].to_s + next_char
        subtrie[next_char] = construct_trie(subtrie[next_char], chars_remaining[1..-1], entry_data, depth + 1)
      end
      subtrie
    end
  end
end
