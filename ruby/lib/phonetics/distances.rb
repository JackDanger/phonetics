# frozen_string_literal: true

require 'delegate'
require 'set'

# Phonetics distance metric.
#
# The metric here is the per-phoneme cost that the Levenshtein algorithm
# (lib/phonetics/levenshtein.rb and ext/c_levenshtein/levenshtein.c) consumes
# as its substitution cost. It returns a value in [0, 1] for every pair of
# phonemes, with two design constraints:
#
#   1. Identical phonemes have distance 0.
#   2. Vowels are closer to vowels, consonants to consonants, and there is a
#      structured (non-flat) cross-class bridge for the approximants and
#      glottals that English perception treats as vowel-adjacent.
#
# Vowel distance is computed in Bark-Euclidean space rather than raw Hz. F1
# and F2 are converted with Traunmüller's approximation so that perceptual
# distance, not acoustic distance, drives the metric. Rounding and rhoticity
# are recorded as discrete additive penalties on top of formant distance.
#
# Consonant distance is the sum of three terms:
#
#   - a small voicing penalty (the Mad-Gab-friendly cheap edit),
#   - a manner-of-articulation distance based on perceptual ranks of the
#     sonority hierarchy,
#   - a place-of-articulation distance in a 2D anatomical embedding (instead
#     of the old 1D column index, which incorrectly put labio-velar /w/ next
#     to bilabial /m/ and far from velar /k/).
module Phonetics
  extend self

  # Suprasegmental and modifier diacritics. Each character either attaches to
  # the preceding base phoneme (length, aspiration, palatalization, etc.) or
  # to the following base phoneme (stress marks, which in IPA precede the
  # stressed syllable). The tokenizer absorbs them into the same token; the
  # distance metric charges a small additive cost when modifiers differ.
  TrailingDiacritics = {
    'ː' => :long,
    'ˑ' => :half_long,
    'ʰ' => :aspirated,
    'ʲ' => :palatalized,
    'ˤ' => :pharyngealized,
    'ˠ' => :velarized,
    "̃" => :nasalized, # combining tilde above
  }.freeze

  LeadingDiacritics = {
    'ˈ' => :primary_stress,
    'ˌ' => :secondary_stress,
  }.freeze

  Diacritics = TrailingDiacritics.merge(LeadingDiacritics).freeze

  # Additive cost when a given modifier is present on one phoneme but not the
  # other. Tuned so single diacritic mismatches add roughly the same as a
  # rounding flip in vowels (~0.05) — meaningful but not dominant.
  DiacriticPenalty = {
    long:              0.05,
    half_long:         0.025,
    aspirated:         0.04,
    palatalized:       0.06,
    pharyngealized:    0.07,
    velarized:         0.07,
    nasalized:         0.06,
    primary_stress:    0.05,
    secondary_stress:  0.03,
  }.freeze
  DEFAULT_DIACRITIC_PENALTY = 0.03

  # This subclass of the stdlib's String allows us to iterate over each
  # phoneme in a string. Longest-prefix matching means atomic multi-character
  # phonemes (/tʃ/, /aɪ/, /ɝ/, …) are recognised as one symbol, and
  # diacritics are absorbed into the token they modify.
  #
  # Usage:
  #   Phonetics::String.new("ˈstuːpɪd").each_phoneme.to_a
  #   => ["ˈs", "t", "uː", "p", "ɪ", "d"]
  class String < SimpleDelegator
    # Group all phonemes by character count, longest first. The downstream
    # `each_phoneme` walks descending so multi-character phonemes win over
    # their single-character constituents.
    def self.phonemes_by_length
      @phonemes_by_length ||= Phonetics.phonemes.each_with_object(
        4 => Set.new, 3 => Set.new, 2 => Set.new, 1 => Set.new
      ) do |str, acc|
        acc[str.chars.size] << str
      end
    end

    # Invalidated when the phoneme inventory changes (e.g. tests that add new
    # symbols). Called rarely; kept private to the test infrastructure.
    def self.reset_phoneme_index!
      @phonemes_by_length = nil
    end

    def each_phoneme
      idx = 0
      pending_prefix = +''
      Enumerator.new do |y|
        while idx < chars.length
          ch = chars[idx]

          # Stress marks bind forward; carry them onto the next emitted token.
          if Phonetics::LeadingDiacritics.key?(ch)
            pending_prefix << ch
            idx += 1
            next
          end

          matched = nil
          self.class.phonemes_by_length.each do |size, phonemes|
            next unless idx + size <= chars.length

            candidate = chars[idx..idx + size - 1].join
            next unless phonemes.include?(candidate)

            matched = candidate
            idx += size
            break
          end

          if matched
            token = pending_prefix.dup << matched
            pending_prefix = +''
            # Absorb any trailing diacritics that modify this phoneme.
            while idx < chars.length && Phonetics::TrailingDiacritics.key?(chars[idx])
              token << chars[idx]
              idx += 1
            end
            y.yield token
          else
            idx += 1
          end
        end
      end
    end
  end

  # ------------------------------------------------------------------
  # Vowels: Bark-Euclidean distance with rounding/rhoticity penalties
  # ------------------------------------------------------------------

  module Vowels
    extend self

    # F1/F2 in Hz. Values are largely from the cardinal-vowel measurements on
    # Wikipedia (Daniel Jones tradition). A few entries are corrected:
    # /y/ is rounded (was a copy-paste typo), /ə/ no longer duplicates /ʌ/,
    # and /ɝ/ carries an explicit rhotic flag and F3.
    FormantFrequencies = {
      'i' => { F1: 240, F2: 2400, rounded: false },
      'y' => { F1: 235, F2: 2100, rounded: true  },
      'ɪ' => { F1: 300, F2: 2100, rounded: false },
      'e' => { F1: 390, F2: 2300, rounded: false },
      'ø' => { F1: 370, F2: 1900, rounded: true  },
      'ɛ' => { F1: 610, F2: 1900, rounded: false },
      'œ' => { F1: 585, F2: 1710, rounded: true  },
      'a' => { F1: 850, F2: 1610, rounded: false },
      'ɶ' => { F1: 820, F2: 1530, rounded: true  },
      'ɑ' => { F1: 750, F2: 940,  rounded: false },
      'ɒ' => { F1: 700, F2: 760,  rounded: true  },
      'ʌ' => { F1: 600, F2: 1170, rounded: false },
      'ə' => { F1: 500, F2: 1500, rounded: false },
      'ɝ' => { F1: 500, F2: 1350, rounded: false, rhotic: true, F3: 1700 },
      'ɔ' => { F1: 500, F2: 700,  rounded: true  },
      'ɤ' => { F1: 460, F2: 1310, rounded: false },
      'o' => { F1: 360, F2: 640,  rounded: true  },
      'ɯ' => { F1: 300, F2: 1390, rounded: false },
      'æ' => { F1: 690, F2: 1660, rounded: false },
      'u' => { F1: 250, F2: 595,  rounded: true  },
      'ʊ' => { F1: 380, F2: 950,  rounded: true  },
    }.freeze

    # Hz → Bark. Traunmüller (1990) approximation: it's perceptually closer
    # to human pitch resolution than raw Hz and is the standard scale used in
    # vowel-distance work since the 90s.
    def self.bark(hz)
      return 0.0 if hz <= 0

      13.0 * Math.atan(0.00076 * hz) + 3.5 * Math.atan((hz / 7500.0)**2)
    end

    # Pre-computed (F1-Bark, F2-Bark) coordinates for every vowel.
    BarkCoords = FormantFrequencies.each_with_object({}) do |(sym, f), acc|
      acc[sym] = [bark(f[:F1]), bark(f[:F2])].freeze
    end.freeze

    # The largest Bark-Euclidean distance achievable inside the inventory,
    # used as the normaliser so that formant_dist ∈ [0, 1] before scaling.
    BarkSpan = begin
      f1s = BarkCoords.values.map(&:first)
      f2s = BarkCoords.values.map(&:last)
      Math.sqrt((f1s.max - f1s.min)**2 + (f2s.max - f2s.min)**2)
    end

    # Vowels live in a perceptually narrower space than consonants, so we cap
    # the formant contribution well below 1.0. Rounding and rhoticity are
    # added on top as discrete features.
    VOWEL_SCALE       = 0.60
    ROUNDING_PENALTY  = 0.05
    RHOTICITY_PENALTY = 0.20

    def phonemes
      @phonemes ||= FormantFrequencies.keys
    end

    # Distance between two vowels, scaled to [0, 1].
    def distance(phoneme1, phoneme2)
      return 0.0 if phoneme1 == phoneme2

      f1 = FormantFrequencies.fetch(phoneme1)
      f2 = FormantFrequencies.fetch(phoneme2)
      a1, b1 = BarkCoords.fetch(phoneme1)
      a2, b2 = BarkCoords.fetch(phoneme2)

      formant_dist = Math.sqrt((a1 - a2)**2 + (b1 - b2)**2) / BarkSpan
      penalty  = formant_dist * VOWEL_SCALE
      penalty += ROUNDING_PENALTY  if f1[:rounded] != f2[:rounded]
      penalty += RHOTICITY_PENALTY if !!f1[:rhotic] != !!f2[:rhotic]
      [penalty, 1.0].min
    end
  end

  # ------------------------------------------------------------------
  # Consonants: voicing + manner + 2D place
  # ------------------------------------------------------------------

  module Consonants
    extend self

    # This chart (columns 2 through the end, anyway) is a direct port of
    # https://en.wikipedia.org/wiki/International_Phonetic_Alphabet#Letters
    # We store the consonant table in this format to make updating it easier.
    #
    # rubocop:disable Layout/TrailingWhitespace
    ChartData = %(           | Labio-velar | Bi-labial | Labio-dental | Linguo-labial | Dental | Alveolar | Post-alveolar | Retro-flex | Palatal | Velar | Uvular | Pharyngeal | Glottal
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
    )
    # rubocop:enable Layout/TrailingWhitespace

    # Anatomical 2D coordinates for each place column, both in [0, 1].
    #   x: front-of-mouth (0) → back-of-mouth (1)
    #   y: lip-articulator (0) → tongue/throat-articulator (1)
    # Labio-velar sits at the back on x but at the lip end on y because /w/
    # has both lip rounding and velar tongue retraction.
    PositionCoords = {
      'Labio-velar'   => [0.95, 0.05],
      'Bi-labial'     => [0.00, 0.05],
      'Labio-dental'  => [0.10, 0.30],
      'Linguo-labial' => [0.05, 0.55],
      'Dental'        => [0.20, 0.60],
      'Alveolar'      => [0.30, 0.70],
      'Post-alveolar' => [0.40, 0.75],
      'Retro-flex'    => [0.50, 0.80],
      'Palatal'       => [0.60, 0.85],
      'Velar'         => [0.80, 0.90],
      'Uvular'        => [0.90, 0.95],
      'Pharyngeal'    => [0.95, 1.00],
      'Glottal'       => [1.00, 1.00],
    }.freeze

    # Perceptual rank for each manner, in [0, 1]. Drawn from the standard
    # sonority hierarchy with stops at the obstruent end and approximants at
    # the sonorant end. The values are spaced to give "stop vs fricative" a
    # meaningfully larger penalty than "fricative vs lateral fricative".
    MannerScore = {
      'Stop'                   => 0.00,
      'Sibilant fricative'     => 0.50,
      'Non-sibilant fricative' => 0.50,
      'Lateral fricative'      => 0.55,
      'Nasal'                  => 0.70,
      'Tap/flap'               => 0.85,
      'Lateral tap/flap'       => 0.85,
      'Trill'                  => 0.90,
      'Lateral approximant'    => 1.00,
      'Approximant'            => 1.00,
    }.freeze

    VOICING_PENALTY = 0.15
    MANNER_SCALE    = 0.45
    PLACE_SCALE     = 0.30
    PLACE_NORM      = Math.sqrt(2.0)

    # Lateral airflow is a separate articulatory dimension that the manner
    # rank conflates: /l/ and /ɹ/ are both "approximants" but route airflow
    # differently and sound very different. Without this penalty,
    # alveolar /l/ vs alveolar /ɹ/ comes out as distance 0.0.
    LATERAL_PENALTY = 0.10
    LATERAL_MANNERS = Set.new([
      'Lateral fricative',
      'Lateral approximant',
      'Lateral tap/flap',
    ]).freeze

    # rubocop:disable Metrics/CyclomaticComplexity
    # rubocop:disable Metrics/PerceivedComplexity
    # Parse the ChartData into a lookup table where we can retrieve attributes
    # for each phoneme.
    def features
      @features ||= begin
        header, *manners = ChartData.lines

        _, *positions = header.chomp.split(' | ')
        positions.map(&:strip!)

        manners.pop while manners.last.to_s.strip.empty?

        position_indexes = Hash[*positions.each_with_index.to_a.flatten]
        @position_count = positions.size

        manners.each_with_object({}) do |row, phonemes|
          # Pad to one cell per position so editors that strip trailing
          # whitespace don't drop the last (often empty) columns.
          manner, *columns = row.chomp.split(' | ', positions.size + 1)
          manner.strip!
          columns << '' while columns.size < positions.size
          positions.zip(columns).each do |position, phoneme_text|
            next if phoneme_text.nil? || phoneme_text.strip.empty?

            # Strip any trailing `|` that survived split, then collapse runs of
            # internal whitespace so we can pluck the two possible phonemes
            # (voiceless and voiced) from the cell text reliably.
            cleaned = phoneme_text.sub(/\|+\s*\z/, '').rstrip
            next if cleaned.strip.empty?

            data = {
              position: position,
              position_index: position_indexes[position],
              manner: manner,
            }
            unless cleaned[0] == ' '
              symbol = cleaned.chars.take_while { |char| char != ' ' }.join
              cleaned = cleaned[symbol.chars.size..]
              phonemes[symbol] = data.merge(voiced: false)
            end
            unless cleaned.strip.empty?
              symbol = cleaned.strip.chars.take_while { |char| char != ' ' }.join
              phonemes[symbol] = data.merge(voiced: true)
            end
          end
        end
      end
    end
    # rubocop:enable Metrics/CyclomaticComplexity
    # rubocop:enable Metrics/PerceivedComplexity

    def phonemes
      @phonemes ||= features.keys
    end

    # Distance between two consonants, scaled to [0, 1].
    def distance(phoneme1, phoneme2)
      return 0.0 if phoneme1 == phoneme2

      f1 = features.fetch(phoneme1)
      f2 = features.fetch(phoneme2)

      penalty  = 0.0
      penalty += VOICING_PENALTY if f1[:voiced] != f2[:voiced]
      penalty += MANNER_SCALE * (MannerScore[f1[:manner]] - MannerScore[f2[:manner]]).abs
      penalty += LATERAL_PENALTY if lateral?(f1[:manner]) != lateral?(f2[:manner])

      x1, y1 = PositionCoords[f1[:position]]
      x2, y2 = PositionCoords[f2[:position]]
      penalty += PLACE_SCALE * Math.sqrt((x1 - x2)**2 + (y1 - y2)**2) / PLACE_NORM

      [penalty, 1.0].min
    end

    def lateral?(manner)
      LATERAL_MANNERS.include?(manner)
    end
  end

  # ------------------------------------------------------------------
  # Cross-class bridge: approximants and glottals near vowels
  # ------------------------------------------------------------------

  # English perception treats /j/, /w/, /ɹ/, /ɰ/ as non-syllabic versions of
  # /i/, /u/, /ɝ/, /ɯ/ respectively — Mad Gab's "yes" ≈ "Es", "wood" ≈ "ood"
  # rely on this bridge. Glottals are mostly an air pulse and are nearer to
  # the surrounding vowels than to a stop or fricative.
  ApproximantVowelBridge = {
    'j' => { 'i' => 0.10, 'ɪ' => 0.14, 'y' => 0.18, 'e' => 0.22 },
    'w' => { 'u' => 0.10, 'ʊ' => 0.14, 'o' => 0.22, 'ɔ' => 0.30, 'ɯ' => 0.20 },
    'ɹ' => { 'ɝ' => 0.08, 'ə' => 0.25 },
    'ɰ' => { 'ɯ' => 0.10, 'u'  => 0.20 },
  }.freeze

  GlottalBridge = {
    'h' => 0.50,
    'ɦ' => 0.50,
    'ʔ' => 0.55,
  }.freeze

  # Default distance when a consonant and vowel meet without a specific bridge.
  # Lower than the old hard 1.0 — phonetic feature systems treat consonants and
  # vowels as overlapping in sonority, not orthogonal.
  CROSS_CLASS_DEFAULT     = 0.85
  CROSS_CLASS_NEAR_BRIDGE = 0.55

  # ------------------------------------------------------------------
  # Compound phonemes: diphthongs and affricates as atomic symbols
  # ------------------------------------------------------------------
  #
  # English (and many other languages) realise diphthongs and affricates as
  # single perceptual units even though their IPA notation is two characters.
  # The tokenizer recognises them as one phoneme (longest-prefix match), and
  # their distance is the average pairwise distance of their components.
  #
  # We include both /aɪ/ (Wiktionary/RP) and /ɑɪ/ (CMU) forms because real-
  # world transcriptions span both traditions.
  Compounds = {
    # diphthongs
    'aɪ' => %w[a ɪ],
    'ɑɪ' => %w[ɑ ɪ],
    'aʊ' => %w[a ʊ],
    'ɑʊ' => %w[ɑ ʊ],
    'ɔɪ' => %w[ɔ ɪ],
    'eɪ' => %w[e ɪ],
    'oʊ' => %w[o ʊ],
    'əʊ' => %w[ə ʊ],
    'ɪə' => %w[ɪ ə],
    'ʊə' => %w[ʊ ə],
    'ɛə' => %w[ɛ ə],
    # affricates
    'tʃ' => %w[t ʃ],
    'dʒ' => %w[d ʒ],
    'ts' => %w[t s],
    'dz' => %w[d z],
    'tɕ' => %w[t ɕ],
    'dʑ' => %w[d ʑ],
    'pf' => %w[p f],
  }.freeze

  def phonemes
    @phonemes ||= Vowels.phonemes + Consonants.phonemes + Compounds.keys
  end

  # Classify compounds by the class of their constituents. Diphthongs (both
  # vowels) are vowels; affricates (both consonants) are consonants.
  Symbols = begin
    base = Consonants.phonemes.reduce({}) { |acc, p| acc.update p => :consonant }.merge(
      Vowels.phonemes.reduce({}) { |acc, p| acc.update p => :vowel }
    )
    Compounds.each do |sym, parts|
      classes = parts.map { |p| base[p] }.uniq
      base[sym] = classes.size == 1 ? classes.first : :compound
    end
    base.freeze
  end

  def distance(phoneme1, phoneme2)
    return 0 if phoneme1 == phoneme2

    base1, mods1 = decompose(phoneme1)
    base2, mods2 = decompose(phoneme2)

    base_dist = if base1 == base2
                  0.0
                elsif distance_map.key?(base1) && distance_map[base1].key?(base2)
                  distance_map[base1][base2]
                else
                  CROSS_CLASS_DEFAULT
                end

    [base_dist + diacritic_distance(mods1, mods2), 1.0].min
  end

  # Split a token into its base phoneme symbol and a set of diacritic kinds.
  # Unrecognised characters stay in the base so a misspelt input doesn't
  # silently lose information.
  def decompose(token)
    return [token, []] if Compounds.key?(token) # fast path: registered atom
    return [token, []] if Symbols.key?(token)

    base = +''
    mods = []
    token.each_char do |c|
      if (kind = Diacritics[c])
        mods << kind
      else
        base << c
      end
    end
    [base, mods]
  end

  # Symmetric-difference cost between two diacritic sets.
  def diacritic_distance(mods1, mods2)
    return 0.0 if mods1.empty? && mods2.empty?

    diff = (mods1 - mods2) + (mods2 - mods1)
    diff.sum { |m| DiacriticPenalty.fetch(m, DEFAULT_DIACRITIC_PENALTY) }
  end

  def distance_map
    @distance_map ||= phonemes.permutation(2).each_with_object(Hash.new { |h, k| h[k] = {} }) do |pair, scores|
      p1, p2 = *pair
      score = _distance(p1, p2)
      scores[p1][p2] = score
      scores[p2][p1] = score
    end
  end

  private

  def _distance(phoneme1, phoneme2)
    c1 = Compounds[phoneme1]
    c2 = Compounds[phoneme2]
    return compound_distance(c1 || [phoneme1], c2 || [phoneme2]) if c1 || c2

    types = [Symbols.fetch(phoneme1), Symbols.fetch(phoneme2)].sort
    case types
    when %i[consonant vowel]
      cross_class_distance(phoneme1, phoneme2)
    when %i[vowel vowel]
      Vowels.distance(phoneme1, phoneme2)
    when %i[consonant consonant]
      Consonants.distance(phoneme1, phoneme2)
    end
  end

  # Distance between two compound (or compound-and-simple) phonemes is the
  # average of their pairwise component distances. The shorter sequence is
  # padded by repeating its last segment so a diphthong against its nucleus
  # vowel charges half a phoneme distance rather than nothing.
  def compound_distance(c1, c2)
    n = [c1.size, c2.size].max
    a = c1 + Array.new(n - c1.size, c1.last)
    b = c2 + Array.new(n - c2.size, c2.last)
    total = a.zip(b).sum { |x, y| x == y ? 0.0 : _distance(x, y) }
    total / n.to_f
  end

  # Cross-class distance: look the consonant up in the bridge tables; if
  # nothing matches, fall back to a high constant. We never return the old
  # flat 1.0 because the levenshtein layer reserves 1.0 for indel cost.
  def cross_class_distance(phoneme1, phoneme2)
    consonant, vowel = Symbols[phoneme1] == :consonant ? [phoneme1, phoneme2] : [phoneme2, phoneme1]

    if (table = ApproximantVowelBridge[consonant])
      return table[vowel] || CROSS_CLASS_NEAR_BRIDGE
    end
    return GlottalBridge[consonant] if GlottalBridge.key?(consonant)

    CROSS_CLASS_DEFAULT
  end
end
