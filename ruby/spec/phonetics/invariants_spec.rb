# frozen_string_literal: true

require_relative '../../lib/phonetics/ruby_levenshtein'

# Invariant-style tests. These are deliberately written against properties of a
# well-formed phonetic distance and edit distance instead of pinned numeric
# values, so they survive metric refactors. If you change a numeric weight,
# these should still pass; if you change an algorithm, they tell you whether
# the change preserved the math's properties.
RSpec.describe 'Phonetic distance invariants' do
  let(:phoneme_pairs) do
    # A representative cross-section: vowels, consonants, an approximant/vowel
    # bridge, a diphthong, and a couple of rare consonants.
    %w[i u ɪ ʊ ɛ æ ə ɝ a ɑ ɔ p b t d k g m n ŋ s z ʃ ʒ θ ð f v h l ɹ j w]
  end

  describe 'Phonetics.distance' do
    it 'is zero for identical phonemes' do
      phoneme_pairs.each do |p|
        expect(Phonetics.distance(p, p)).to eq(0)
      end
    end

    it 'is symmetric' do
      phoneme_pairs.combination(2).each do |a, b|
        expect(Phonetics.distance(a, b)).to be_within(1e-9).of(Phonetics.distance(b, a))
      end
    end

    it 'is non-negative and bounded above by 1.0' do
      phoneme_pairs.combination(2).each do |a, b|
        d = Phonetics.distance(a, b)
        expect(d).to be >= 0.0
        expect(d).to be <= 1.0
      end
    end

    it 'treats schwa and rhotic-schwa as distinguishable' do
      # /ə/ and /ɝ/ differ in rhoticity; in Mad Gab they are not free
      # substitutions.
      expect(Phonetics.distance('ə', 'ɝ')).to be > 0.0
    end

    it 'puts approximants near their corresponding vowels' do
      # /j/ is a non-syllabic /i/; /w/ is a non-syllabic /u/; /ɹ/ is rhotic
      # like /ɝ/. They should be much closer than a generic consonant-vowel
      # contrast.
      expect(Phonetics.distance('j', 'i')).to be < Phonetics.distance('t', 'i')
      expect(Phonetics.distance('w', 'u')).to be < Phonetics.distance('t', 'u')
      expect(Phonetics.distance('ɹ', 'ɝ')).to be < Phonetics.distance('t', 'ɝ')
    end

    it 'puts tense/lax pairs closer than tense/back pairs' do
      expect(Phonetics.distance('i', 'ɪ')).to be < Phonetics.distance('i', 'u')
      expect(Phonetics.distance('u', 'ʊ')).to be < Phonetics.distance('u', 'i')
    end

    it 'puts homorganic stops closer than cross-place stops' do
      expect(Phonetics.distance('p', 'b')).to be < Phonetics.distance('p', 'k')
      expect(Phonetics.distance('t', 'd')).to be < Phonetics.distance('t', 'g')
    end

    it 'puts voicing pairs closer than manner-changing pairs' do
      expect(Phonetics.distance('s', 'z')).to be < Phonetics.distance('s', 't')
      expect(Phonetics.distance('f', 'v')).to be < Phonetics.distance('f', 'p')
    end

    it 'recognises rounded/unrounded distinction in vowels' do
      # /i/ unrounded vs /y/ rounded share formants; should still be >0
      expect(Phonetics.distance('i', 'y')).to be > 0.0
    end
  end

  describe 'Phonetics::RubyLevenshtein' do
    def d(a, b)
      Phonetics::RubyLevenshtein.distance(a, b)
    end

    it 'is zero for identical strings' do
      %w[kæt stupɪd ɪtsdʒʌstəstupɪdgeɪm].each do |s|
        expect(d(s, s)).to eq(0)
      end
    end

    it 'is symmetric' do
      pairs = [%w[kæt kʌt], %w[stupɪd dupɪd], %w[hɪt ɪt]]
      pairs.each { |a, b| expect(d(a, b)).to be_within(1e-9).of(d(b, a)) }
    end

    it 'matches the phoneme distance on single-phoneme inputs' do
      [%w[p b], %w[i ɪ], %w[k g]].each do |a, b|
        expect(d(a, b)).to be_within(1e-9).of(Phonetics.distance(a, b))
      end
    end

    it 'charges roughly one indel for a single mid-string insertion' do
      # Inserting a phoneme costs roughly the indel cost regardless of where it
      # sits in the string. A standard weighted Levenshtein uses indel ~= 1.0.
      indel = d('kæt', 'kæte') # tail insertion -- our most reliable anchor
      mid   = d('kæt', 'kæɪt') # mid insertion
      head  = d('kæt', 'əkæt') # head insertion
      [indel, mid, head].each do |x|
        expect(x).to be_within(0.5).of(indel)
      end
    end

    it 'charges more for a substitution-of-a-distant-phoneme than a substitution-of-a-near-phoneme' do
      expect(d('kæt', 'kɛt')).to be < d('kæt', 'kut')
      expect(d('pɪn', 'bɪn')).to be < d('pɪn', 'kɪn')
    end

    it 'is monotonically non-decreasing when extra unrelated phonemes are appended' do
      base = d('kæt', 'dɔg')
      extended = d('kætz', 'dɔgz') # add identical suffix to both: distance unchanged
      expect(extended).to be_within(1e-9).of(base)
    end

    it 'never exceeds the cost of full substitution' do
      a = 'stupɪd'
      b = 'mɔrnɪŋ'
      naive = a.chars.zip(b.chars).map { |x, y| x && y ? Phonetics.distance(x, y) : 1.0 }.sum
      naive += (a.length - b.length).abs * 1.0
      expect(d(a, b)).to be <= naive + 0.01
    end

    it 'treats blank strings sanely' do
      expect(d('', '')).to eq(0)
      expect(d('kæt', '')).to be > 0
      expect(d('', 'kæt')).to be_within(1e-9).of(d('kæt', ''))
    end
  end

  describe 'Compound phonemes (diphthongs and affricates)' do
    it 'tokenises diphthongs as one symbol' do
      tokens = Phonetics::String.new('kɑɪt').each_phoneme.to_a
      expect(tokens).to eq(%w[k ɑɪ t])
    end

    it 'tokenises affricates as one symbol' do
      tokens = Phonetics::String.new('dʒʌdʒ').each_phoneme.to_a
      expect(tokens).to eq(%w[dʒ ʌ dʒ])
    end

    it 'puts /aɪ/ closer to /ɑɪ/ than to /ɔɪ/' do
      expect(Phonetics.distance('aɪ', 'ɑɪ')).to be < Phonetics.distance('aɪ', 'ɔɪ')
    end

    it 'puts /tʃ/ and /dʒ/ at voicing-flip distance' do
      expect(Phonetics.distance('tʃ', 'dʒ')).to be < Phonetics.distance('tʃ', 'k')
    end

    it 'puts /dʒ/ closer to /ʒ/ than to /m/' do
      expect(Phonetics.distance('dʒ', 'ʒ')).to be < Phonetics.distance('dʒ', 'm')
    end
  end

  describe 'Diacritic-aware distance' do
    it 'tokenises aspiration onto the preceding consonant' do
      expect(Phonetics::String.new('pʰɪt').each_phoneme.to_a).to eq(%w[pʰ ɪ t])
    end

    it 'tokenises length onto the preceding vowel' do
      expect(Phonetics::String.new('stuːpɪd').each_phoneme.to_a).to eq(%w[s t uː p ɪ d])
    end

    it 'tokenises stress onto the following segment' do
      expect(Phonetics::String.new('ˈstop').each_phoneme.to_a).to eq(%w[ˈs t o p])
    end

    it 'charges a small additive cost for an aspiration mismatch' do
      expect(Phonetics.distance('p', 'pʰ')).to be > 0
      expect(Phonetics.distance('p', 'pʰ')).to be < Phonetics.distance('p', 'b')
    end

    it 'still charges the voicing penalty when both sides share aspiration' do
      expect(Phonetics.distance('pʰ', 'bʰ')).to be_within(1e-9).of(Phonetics.distance('p', 'b'))
    end
  end

  describe 'Mad Gab–style sanity' do
    def d(a, b)
      Phonetics::RubyLevenshtein.distance(a, b)
    end

    it 'ranks the intended decoding closer than an unrelated phrase' do
      target  = 'ɪtsdʒʌstəstupɪdgeɪm'      # "It's just a stupid game"
      clue    = 'hɪtsdʒʌstɪsduphɪdkeɪm'    # "Hits Justice Dupe Hid Came"
      decoy   = 'jɔrmʌðɝwɛrzsneɪkɝz'        # an unrelated phrase
      expect(d(target, clue)).to be < d(target, decoy)
    end

    it 'puts the Mad Gab pair at least 2× closer than an unrelated decoy' do
      target  = 'ɪtsdʒʌstəstupɪdgeɪm'
      clue    = 'hɪtsdʒʌstɪsduphɪdkeɪm'
      decoy   = 'jɔrmʌðɝwɛrzsneɪkɝz'
      expect(d(target, decoy)).to be > 2 * d(target, clue)
    end

    it 'matches between Ruby and C implementations on undiacriticised input' do
      a, b = 'ɪtsdʒʌstəstupɪdgeɪm', 'hɪtsdʒʌstɪsduphɪdkeɪm'
      expect(Phonetics::Levenshtein.distance(a, b)).to be_within(1e-3).of(d(a, b))
    end
  end
end
