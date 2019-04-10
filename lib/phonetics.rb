require 'delegate'

module Phonetics
  extend self

  # This subclass of the stdlib's String allows us to iterate over each phoneme
  # in a string without monkeypatching
  #
  # Usage:
  #   Phonetics::String.new("wətɛvɝ").each_phoneme.to_a
  #   => ["w", "ə", "t", "ɛ", "v", "ɝ"]
  class String < SimpleDelegator

    # Group all phonemes by how many characters they have. Use this to walk
    # through a string finding phonemes (looking for longest ones first)
    def self.phonemes_by_length
      @phonemes_by_length ||= Phonetics.phonemes.each_with_object(
        # This relies on the impicit stable key ordering of Hash objects in Ruby
        # 2+ to keep the keys in descending order.
        4 => Set.new, 3 => Set.new, 2 => Set.new, 1 => Set.new
      ) do |str, acc|
        acc[str.chars.size] << str
      end
    end

    def each_phoneme
      idx = 0
      Enumerator.new do |y|
        while idx < chars.length
          found = false
          self.class.phonemes_by_length.each do |size, phonemes|
            if idx + size <= chars.length
              candidate = chars[idx..idx+size-1].join
              if phonemes.include?(candidate)
                y.yield candidate
                idx += size
                found = true
                break
              else
              end
            end
          end
          idx += 1 unless found
        end
      end
    end
  end

  module Vowels
    extend self

    FormantFrequencies = {
      # https://en.wikipedia.org/wiki/Formant#Phonetics
      'i' => { F1: 240, F2: 2400, rounded: false },
      'y' => { F1: 235, F2: 2100, rounded: false },
      'ɪ' => { F1: 300, F2: 2100, rounded: false }, # Guessing From other vowels
      'e' => { F1: 390, F2: 2300, rounded: false },
      'ø' => { F1: 370, F2: 1900, rounded: true },
      'ɛ' => { F1: 610, F2: 1900, rounded: false },
      'œ' => { F1: 585, F2: 1710, rounded: true },
      'a' => { F1: 850, F2: 1610, rounded: false },
      'ɶ' => { F1: 820, F2: 1530, rounded: true },
      'ɑ' => { F1: 750, F2: 940,  rounded: false },
      'ɒ' => { F1: 700, F2: 760,  rounded: true },

      'ʌ' => { F1: 600, F2: 1170, rounded: false },
      # copying 'ʌ' for other mid-vowel formants
      'ə' => { F1: 600, F2: 1170, rounded: false },
      'ɝ' => { F1: 600, F2: 1170, rounded: false, rhotic: true },

      'ɔ' => { F1: 500, F2: 700,  rounded: true },
      'ɤ' => { F1: 460, F2: 1310, rounded: false },
      'o' => { F1: 360, F2: 640,  rounded: true },
      'ɯ' => { F1: 300, F2: 1390, rounded: false },
      'æ' => { F1: 800, F2: 1900, rounded: false }, # Guessing From other vowels
      'u' => { F1: 350, F2: 650,  rounded: true }, # Guessing From other vowels
      'ʊ' => { F1: 350, F2: 650,  rounded: true },
      # Frequencies from http://videoweb.nie.edu.sg/phonetic/vowels/measurements.html
    }

    def phonemes
      @phonemes ||= FormantFrequencies.keys
    end

    # Given two vowels, calculate the (pythagorean) distance between them using
    # their F1 and F2 frequencies as x/y coordinates.
    # The return value is scaled to a value between 0 and 1
    # TODO: account for rhoticity (F3)
    def distance(phoneme1, phoneme2)
      formants1 = FormantFrequencies.fetch(phoneme1)
      formants2 = FormantFrequencies.fetch(phoneme2)

      @minmax_f1 ||= FormantFrequencies.values.minmax {|a, b| a[:F1] <=> b[:F1] }.map {|h| h[:F1] }
      @minmax_f2 ||= FormantFrequencies.values.minmax {|a, b| a[:F2] <=> b[:F2] }.map {|h| h[:F2] }

      # Get an x and y value for each input phoneme scaled between 0.0 and 1.0
      # We'll use the scaled f1 as the 'x' and the scaled f2 as the 'y'
      scaled_phoneme1_f1 = (formants1[:F1] - @minmax_f1[0]) / @minmax_f1[1].to_f
      scaled_phoneme1_f2 = (formants1[:F2] - @minmax_f2[0]) / @minmax_f2[1].to_f
      scaled_phoneme2_f1 = (formants2[:F1] - @minmax_f1[0]) / @minmax_f1[1].to_f
      scaled_phoneme2_f2 = (formants2[:F2] - @minmax_f2[0]) / @minmax_f2[1].to_f

      f1_distance = (scaled_phoneme1_f1 - scaled_phoneme2_f1).abs
      f2_distance = (scaled_phoneme1_f2 - scaled_phoneme2_f2).abs

      # When we have four values we can use the pythagorean theorem on them
      # (order doesn't matter)
      Math.sqrt((f1_distance ** 2) + (f2_distance ** 2))
    end
  end

  module Consonants
    extend self

    # Plosives and fricatives are less similar than trills and flaps, or
    # sibilant fricatives and non-sibilant fricatives
    # TODO: this is unfinished and possibly a bad idea
    MannerDistances = {
      'Nasal'                  => %w[continuant],
      'Stop'                   => %w[],
      'Sibilant fricative'     => %w[continuant fricative],
      'Non-sibilant fricative' => %w[continuant non_sibilant fricative],
      'Approximant'            => %w[],
      'Tap/Flap'               => %w[],
      'Trill'                  => %w[],
      'Lateral fricative'      => %w[continuant fricative],
      'Lateral approximant'    => %w[],
      'Lateral tap/flap'       => %w[],
    }.freeze

    # This chart (columns 2 through the end, anyway) is a direct port of
    # https://en.wikipedia.org/wiki/International_Phonetic_Alphabet#Letters
    # We # store the consonant table in this format to make updating it easier.
    ChartData = %Q{          | Labio-velar | Bi-labial | Labio-dental | Linguo-labial | Dental | Alveolar | Post-alveolar | Retro-flex | Palatal | Velar | Uvular | Pharyngeal | Glottal
      Nasal                  |             | m̥  m      |    ɱ         |    n̼          |        | n̥  n     |               | ɳ̊  ɳ       | ɲ̊  ɲ    | ŋ̊  ŋ  |    ɴ   |            |        
      Stop                   |             | p  b      | p̪  b̪         | t̼  d̼          |        | t  d     |               | ʈ  ɖ       | c  ɟ    | k  g  | q  ɢ   | ʡ          | ʔ      
      Sibilant fricative     |             |           |              |               |        | s  z     | ʃ  ʒ          | ʂ  ʐ       | ɕ  ʑ    |       |        |            |        
      Non-sibilant fricative |             | ɸ  β      | f  v         | θ̼  ð̼          | θ  ð   | θ̠  ð̠     | ɹ̠̊˔ ɹ̠˔         |    ɻ˔      | ç  ʝ    | x  ɣ  | χ  ʁ   | ħ  ʕ       | h  ɦ   
      Approximant            |   w         |           | ʋ̥  ʋ         |               |        | ɹ̥  ɹ     |               | ɻ̊  ɻ       | j̊  j    | ɰ̊  ɰ  |        |            |    ʔ̞   
      Tap/flap               |             |    ⱱ̟      |    ⱱ         |    ɾ̼          |        | ɾ̥  ɾ     |               | ɽ̊  ɽ       |         |       |    ɢ̆   |    ʡ̆       |        
      Trill                  |             | ʙ̥  ʙ      |              |               |        | r̥  r     |               |            |         |       | ʀ̥  ʀ   | ʜ  ʢ       |        
      Lateral fricative      |             |           |              |               |        | ɬ  ɮ     |               | ɭ̊˔ ɭ˔      | ʎ̝̊  ʎ̝    | ʟ̝̊  ʟ̝  |        |            |        
      Lateral approximant    |             |           |              |               |        | l̥  l     |               | ɭ̊  ɭ       | ʎ̥  ʎ    | ʟ̥  ʟ  |    ʟ̠   |            |        
      Lateral tap/flap       |             |           |              |               |        |    ɺ     |               |    ɭ̆       |    ʎ̆    |    ʟ̆  |        |            |         
    }

    # Parse the ChartData into a lookup table where we can retrieve attributes
    # for each phoneme
    def features
      @features ||= begin 
        header, *manners = ChartData.lines

        _, *positions = header.chomp.split(' | ')
        positions.map(&:strip!)

        # Remove any trailing blank lines
        manners.pop while manners.last.to_s.strip.empty?

        position_indexes = Hash[*positions.each_with_index.to_a.flatten]

        @position_count = positions.size

        manners.each_with_object({}) do |row, phonemes|
          manner, *columns = row.chomp.split(' | ')
          manner.strip!
          positions.zip(columns).each do |position, phoneme_text|
            data = {
              position: position,
              position_index: position_indexes[position],
              manner: manner,
            }
            # If there is a character in the first byte then this articulation
            # has a voiceless phoneme. The symbol may use additional characters
            # as part of the phoneme symbol.
            unless phoneme_text[0] == ' '
              # Take the first non-blank character string
              symbol = phoneme_text.chars.take_while { |char| char != ' ' }.join
              phoneme_text = phoneme_text[symbol.chars.size..-1]

              phonemes[symbol] = data.merge(voiced: false)
            end
            # If there's a character anywhere left in the string then this
            # articulation has a voiced phoneme
            unless phoneme_text.strip.empty?
              symbol = phoneme_text.strip
              phonemes[symbol] = data.merge(voiced: true)
            end
          end
        end
      end
    end

    def phonemes
      @phonemes ||= features.keys
    end

    # Given two consonants, calculate their difference by summing the
    # following:
    #   * 0.1 if they are not voiced the same
    #   * 0.3 if they are different manners
    #   * Up to 0.6 if they are the maximum position difference
    def distance(phoneme1, phoneme2)
      features1 = features[phoneme1]
      features2 = features[phoneme2]

      penalty = 0
      penalty += 0.1 if features1[:voiced] != features2[:voiced]

      penalty += 0.3 if features1[:manner] != features2[:manner]

      # Use up to the remaining 0.6 for penalizing differences in manner
      penalty += 0.6 * ((features1[:position_index] - features2[:position_index]).abs / @position_count.to_f)
      penalty
    end
  end

  def phonemes
    Consonants.phonemes + Vowels.phonemes
  end

  Symbols = Consonants.phonemes.reduce({}) {|acc, p| acc.update p => :consonant }.merge(
    Vowels.phonemes.reduce({}) { |acc, p| acc.update p => :vowel }
  )

  def distance(phoneme1, phoneme2)
    types = [Symbols.fetch(phoneme1), Symbols.fetch(phoneme2)].sort
    if types == [:consonant, :vowel]
      1.0
    elsif types == [:vowel, :vowel]
      Vowels.distance(phoneme1, phoneme2)
    elsif types == [:consonant, :consonant]
      Consonants.distance(phoneme1, phoneme2)
    end
  end

  def distance_map
    @distance_map ||= (
      Vowels.phonemes + Consonants.phonemes
    ).permutation(2).each_with_object(Hash.new { |h, k| h[k] = {} } ) do |pair, scores|
      p1, p2 = *pair
      score = distance(p1, p2)
      scores[p1][p2] = score
      scores[p2][p1] = score
    end
  end
end
