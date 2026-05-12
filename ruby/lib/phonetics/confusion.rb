# frozen_string_literal: true

require 'set'
require_relative '../phonetics'

# Listener-confusion distance over IPA phonemes.
#
# Where Phonetics::Levenshtein gives the strict edit-distance between two
# phonemic sequences using a weighted per-phoneme cost, this module gives the
# *perceptual* distance: how likely a native English listener is to confuse
# the two streams. Calibrated against Mad Gab puzzle data, which encodes a
# real natural-speech phenomenon: humans systematically resyllabify a stream
# of phones into a different lexical sequence and need only a soft set of
# acoustic cues to bridge between the two.
#
# Three modifications to standard weighted Levenshtein:
#
#   1. AFFINE GAP PENALTIES (Gotoh 1982). Opening a new alignment gap costs
#      GAP_OPEN; extending an existing gap costs GAP_EXTEND, where
#      GAP_EXTEND << GAP_OPEN. Mad Gab clues typically preserve the target's
#      phoneme sequence and add filler phonemes at word boundaries — that
#      filler manifests as a single contiguous gap, which a fixed indel
#      penalty would over-charge but an affine penalty handles correctly.
#
#   2. WEAK-PHONEME INDEL DISCOUNT. /ə/, /h/, /ʔ/, /ɦ/ are routinely
#      inserted, dropped, or hallucinated in casual English speech. Their
#      indel cost is WEAK_INDEL_COST, well below GAP_OPEN. This is the
#      mechanism by which "Hits Justice Dupe Hid Came" can absorb a non-
#      existent /h/ at every word start without much penalty.
#
#   3. EXPLICIT TWO-TIER API. Callers who want the raw acoustic distance
#      (clustering accents, comparing dialect transcriptions, modelling
#      ASR error) use Phonetics::Levenshtein. Callers who want the
#      perceptual judgement (Mad Gab solving, pun detection, mondegreen
#      analysis, mishearings) use Phonetics::Confusion.
#
# Public surface:
#
#   Phonetics::Confusion.distance(ipa1, ipa2)
#   Phonetics::Confusion.similarity(ipa1, ipa2)  # 1.0 - normalised distance
#   Phonetics::RubyConfusion.new(...).distance   # for verbose tracing
module Phonetics
  module Confusion
    extend self

    # Cost of starting a new gap (insertion or deletion of one phoneme that
    # isn't preceded by another insertion/deletion in the same direction).
    # Slightly higher than the largest typical sub cost on a "close" pair
    # so the algorithm prefers matching over skipping when phonemes are
    # mildly similar.
    GAP_OPEN = 0.60

    # Cost of extending an already-open gap by one more phoneme. Below
    # GAP_OPEN (so multi-phoneme re-syllabification at word boundaries is
    # cheap), but high enough that an unrelated string can't trivially
    # "skip-gap" itself into alignment with the target. Calibrated against
    # the Mad Gab corpus: this is roughly the per-phoneme penalty needed
    # to keep an unrelated phrase from out-scoring a real clue.
    GAP_EXTEND = 0.25

    # Phonemes that are perceptually transparent at word boundaries in
    # English. Indels of these always use WEAK_INDEL_COST regardless of
    # whether they're opening or extending a gap. The set is informed by
    # English speech-reduction literature (Bybee, Fokes & Bond) — these
    # are the segments with the highest measured deletion/insertion rates
    # in natural conversational speech.
    WEAK_PHONEMES = Set.new(%w[ə h ʔ ɦ]).freeze
    WEAK_INDEL_COST = 0.15

    # The word-boundary token is even cheaper to indel than a weak phoneme.
    # Mad Gab is fundamentally a re-syllabification operation: the surface
    # form rearranges word boundaries without changing the underlying
    # phoneme stream. Charging meaningfully for a boundary indel would
    # punish exactly the operation we want to track.
    BOUNDARY_INDEL_COST = 0.02

    # Empirically-confusable phoneme pairs whose acoustic distance under
    # Phonetics.distance overstates the perceptual gap. Drawn from the
    # Miller-Nicely (1955) consonant-confusion lineage and English-
    # variation studies (th-stopping, intervocalic /t/-flapping, the
    # canonical l/r confusion).
    #
    # The overlay is one-directional in the look-up but symmetric in
    # interpretation: presence of the pair {a,b} sets sub_cost(a,b) and
    # sub_cost(b,a) both to the overlay value.
    #
    # Strict Phonetics.distance is unaffected — only the Confusion path
    # consults this table.
    EMPIRICAL_OVERLAY = {
      # Th-stopping: /θ/→/t/, /ð/→/d/ (very common in casual speech,
      # AAVE, NYC English, and L2 English).
      Set[ 'θ', 't' ]  => 0.18,
      Set[ 'ð', 'd' ]  => 0.18,
      # Th-stopping into sibilants: less common but documented.
      Set[ 'θ', 's' ]  => 0.12,
      Set[ 'ð', 'z' ]  => 0.12,
      # Fric-stop crossing at the same place (the "p/f", "b/v" cousins).
      Set[ 'p', 'f' ]  => 0.20,
      Set[ 'b', 'v' ]  => 0.20,
      Set[ 't', 's' ]  => 0.20,
      Set[ 'd', 'z' ]  => 0.20,
      # Intervocalic /t/-flapping in American English: 'butter' ≈ 'budder'
      # ≈ 'buɾer'. The flap [ɾ] is acoustically nearly indistinguishable
      # from a brief voiced [d] between vowels.
      Set[ 't', 'ɾ' ]  => 0.10,
      Set[ 'd', 'ɾ' ]  => 0.05,
      # L/R confusion (universally high-confusion pair for L2 English;
      # the lateral fix already drops it to 0.10 acoustically, the
      # overlay pushes it slightly higher to reflect perceptual reality).
      Set[ 'l', 'ɹ' ]  => 0.15,
    }.freeze

    # Convenience: top-level entry point.
    def distance(ipa1, ipa2, verbose: false)
      RubyConfusion.new(ipa1, ipa2, verbose: verbose).distance
    end

    # 0..1 normalised similarity score. Worst case is one substitution per
    # position in the longer string, so dividing by max(len) gives a
    # bounded-range judgement comparable across phrase lengths.
    def similarity(ipa1, ipa2)
      a = Phonetics::String.new(ipa1).each_phoneme(boundaries: true).to_a
      b = Phonetics::String.new(ipa2).each_phoneme(boundaries: true).to_a
      max_n = [a.size, b.size].max
      return 1.0 if max_n.zero?

      d = RubyConfusion.new(ipa1, ipa2).distance
      [1.0 - (d.to_f / max_n), 0.0].max
    end

    # Per-phoneme substitution cost used by the confusion DP. Consults the
    # empirical overlay first, then falls back to Phonetics.distance, which
    # already handles compound phonemes (diphthongs/affricates), cross-class
    # bridges, and diacritics.
    def sub_cost(a, b)
      return 0.0 if a == b

      overlay = EMPIRICAL_OVERLAY[Set[a, b]]
      return overlay if overlay

      Phonetics.distance(a, b)
    end

    def weak?(phoneme)
      WEAK_PHONEMES.include?(phoneme) || phoneme == Phonetics::BOUNDARY_TOKEN
    end

    # Per-phoneme indel cost. The word-boundary token is at the bottom of
    # the cost ladder (re-syllabification is free); other weak phonemes
    # use WEAK_INDEL_COST; everything else falls back to the affine
    # GAP_OPEN/GAP_EXTEND machinery.
    def weak_indel_cost(phoneme)
      return BOUNDARY_INDEL_COST if phoneme == Phonetics::BOUNDARY_TOKEN
      return WEAK_INDEL_COST if WEAK_PHONEMES.include?(phoneme)

      nil
    end
  end

  # Pure-Ruby implementation of Confusion.distance. Mirrors the structure of
  # RubyLevenshtein so the two are interchangeable to callers that want a
  # verbose / introspectable distance computation.
  class RubyConfusion
    INF = Float::INFINITY

    attr_reader :a, :b

    def self.distance(a, b, verbose: false)
      new(a, b, verbose: verbose).distance
    end

    def initialize(a, b, verbose: false)
      @a = Phonetics::String.new(a).each_phoneme(boundaries: true).to_a
      @b = Phonetics::String.new(b).each_phoneme(boundaries: true).to_a
      @verbose = verbose
    end

    def distance
      m = a.size
      n = b.size
      return 0.0 if m.zero? && n.zero?
      return seed_cost(b) if m.zero?
      return seed_cost(a) if n.zero?

      # Three DP matrices for Gotoh's algorithm:
      #   mm[i][j] -- best score ending in a substitution/match at (i, j)
      #   xx[i][j] -- best score ending in a gap that consumes from a
      #   yy[i][j] -- best score ending in a gap that consumes from b
      mm = Array.new(m + 1) { Array.new(n + 1, INF) }
      xx = Array.new(m + 1) { Array.new(n + 1, INF) }
      yy = Array.new(m + 1) { Array.new(n + 1, INF) }
      mm[0][0] = 0.0

      # Seed the gap-only edges. The leftmost column models matching the
      # empty target against successive prefixes of `a`; the top row does
      # the symmetric thing for `b`. Both follow the open-then-extend rule,
      # with weak phonemes overriding both.
      (1..m).each do |i|
        ph = a[i - 1]
        prev = i == 1 ? 0.0 : xx[i - 1][0]
        xx[i][0] = prev + indel_step(ph, opening: i == 1)
      end
      (1..n).each do |j|
        ph = b[j - 1]
        prev = j == 1 ? 0.0 : yy[0][j - 1]
        yy[0][j] = prev + indel_step(ph, opening: j == 1)
      end

      (1..m).each do |i|
        ai = a[i - 1]
        a_weak = Confusion.weak?(ai)

        (1..n).each do |j|
          bj = b[j - 1]
          b_weak = Confusion.weak?(bj)

          # M: end in a match/mismatch. Can transition from any state.
          best_into_m = [mm[i - 1][j - 1], xx[i - 1][j - 1], yy[i - 1][j - 1]].min
          mm[i][j] = best_into_m + Confusion.sub_cost(ai, bj)

          # X: end in an a-consuming gap. Open a fresh gap from M or Y, or
          # extend an existing X-gap. Weak `a` overrides both costs.
          a_weak_cost = Confusion.weak_indel_cost(ai)
          xx[i][j] =
            if a_weak_cost
              [mm[i - 1][j], xx[i - 1][j], yy[i - 1][j]].min + a_weak_cost
            else
              [
                mm[i - 1][j] + Confusion::GAP_OPEN,
                xx[i - 1][j] + Confusion::GAP_EXTEND,
                yy[i - 1][j] + Confusion::GAP_OPEN,
              ].min
            end

          # Y: end in a b-consuming gap. Symmetric.
          b_weak_cost = Confusion.weak_indel_cost(bj)
          yy[i][j] =
            if b_weak_cost
              [mm[i][j - 1], xx[i][j - 1], yy[i][j - 1]].min + b_weak_cost
            else
              [
                mm[i][j - 1] + Confusion::GAP_OPEN,
                yy[i][j - 1] + Confusion::GAP_EXTEND,
                xx[i][j - 1] + Confusion::GAP_OPEN,
              ].min
            end
        end
      end

      print_matrix(mm, xx, yy) if @verbose
      [mm[m][n], xx[m][n], yy[m][n]].min
    end

    private

    # Edge case: comparing a non-empty string against the empty string. Cost
    # is one gap that extends across every phoneme of the non-empty side
    # (with weak phonemes still discounted individually).
    def seed_cost(phonemes)
      total = 0.0
      phonemes.each_with_index do |ph, i|
        total += indel_step(ph, opening: i.zero?)
      end
      total
    end

    def indel_step(phoneme, opening:)
      cost = Confusion.weak_indel_cost(phoneme)
      return cost if cost

      opening ? Confusion::GAP_OPEN : Confusion::GAP_EXTEND
    end

    def print_matrix(mm, xx, yy)
      puts "Confusion DP for a=#{a.inspect} b=#{b.inspect}"
      [['M', mm], ['X', xx], ['Y', yy]].each do |label, mat|
        puts "#{label} matrix:"
        mat.each { |row| puts '  ' + row.map { |v| v == INF ? '   ∞   ' : '%7.3f' % v }.join(' ') }
      end
    end
  end
end
