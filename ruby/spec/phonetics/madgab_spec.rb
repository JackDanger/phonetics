# frozen_string_literal: true

require 'phonetics'

# Exercise the metric on real Mad Gab puzzles. The contract is:
#
#   distance(target, intended_clue) < distance(target, distractor)
#
# where `distractor` is a length-matched English phrase that's unrelated to
# the target. If this holds across a basket of varied puzzles we can claim
# the metric is genuinely modelling acoustic similarity rather than just
# accidentally working on the one example in the README.
RSpec.describe 'Mad Gab puzzle ranking' do
  # rubocop:disable Layout/LineLength
  PUZZLES = [
    {
      label:      "It's just a stupid game",
      target:     'ɪtsdʒʌstəstupɪdgeɪm',
      clue_phrase: 'Hits Justice Dupe Hid Came',
      clue:       'hɪtsdʒʌstɪsduphɪdkeɪm',
      distractor: 'jɔrmʌðɝwɛrzsneɪkɝz',
    },
    {
      label:      'Apple pie',
      target:     'æpəlpaɪ',
      clue_phrase: 'Ape Pull Pie',
      clue:       'eɪppʊlpaɪ',
      distractor: 'rɑkiroʊd',
    },
    {
      label:      'Machine gun',
      target:     'məʃingʌn',
      clue_phrase: 'Mush Sheen Gum',
      clue:       'mʌʃʃingʌm',
      distractor: 'maʊntɪnrʌn',
    },
    {
      label:      'Need a coffee',
      target:     'nidəkɔfi',
      clue_phrase: 'Knee Dock Hoff Fee',
      clue:       'nidɑkhɔffi',
      distractor: 'reɪtðəmuvi',
    },
    {
      label:      'Master baker',
      target:     'mæstɝbeɪkɝ',
      clue_phrase: 'Mass Stir Bake Her',
      clue:       'mæsstɝbeɪkhɝ',
      distractor: 'lɔstɪnðədɑrk',
    },
    {
      label:      'Sandwich',
      target:     'sænwɪtʃ',
      clue_phrase: 'Sand Wedge',
      clue:       'sændwɛdʒ',
      distractor: 'lɛmənslaɪs',
    },
    {
      label:      'Police state',
      target:     'pəlissteɪt',
      clue_phrase: 'Pole Lease State',
      clue:       'poʊllissteɪt',
      distractor: 'kɑkədutʃiz',
    },
    {
      label:      'Iran',
      target:     'ɪrɑn',
      clue_phrase: 'Hear On',
      clue:       'hɪrɑn',
      distractor: 'bɪgbɛn',
    },
    {
      label:      'Napoleon',
      target:     'nəpoʊliən',
      clue_phrase: 'Knee Cap Old Eon',
      clue:       'nikæpoʊldion',
      distractor: 'sɔrəlɔnmi',
    },
    {
      label:      'I love you',
      target:     'aɪlʌvju',
      clue_phrase: 'Eye Love Ewe',
      clue:       'aɪlʌvju',
      distractor: 'goʊtuslip',
    },
    {
      label:      'Take it easy',
      target:     'teɪkɪtizi',
      clue_phrase: 'Take Cat Ease E',
      clue:       'teɪkkætizi',
      distractor: 'foʊrəklɑkdɑg',
    },
    {
      label:      'Happy birthday',
      target:     'hæpibɝθdeɪ',
      clue_phrase: 'Hat Pee Bird Hay',
      clue:       'hætpibɝdheɪ',
      distractor: 'dʒʌmpɪnsplæʃ',
    },
  ].freeze
  # rubocop:enable Layout/LineLength

  describe 'using the Ruby implementation' do
    PUZZLES.each do |puzzle|
      it "ranks #{puzzle[:clue_phrase].inspect} closer to #{puzzle[:label].inspect} than the distractor" do
        clue_d       = Phonetics::RubyLevenshtein.distance(puzzle[:target], puzzle[:clue])
        distractor_d = Phonetics::RubyLevenshtein.distance(puzzle[:target], puzzle[:distractor])
        expect(clue_d).to be < distractor_d
      end
    end
  end

  describe 'using the C implementation (parity check on undiacriticised input)' do
    PUZZLES.each do |puzzle|
      it "agrees with Ruby for #{puzzle[:label].inspect}" do
        c_clue    = Phonetics::Levenshtein.distance(puzzle[:target], puzzle[:clue])
        ruby_clue = Phonetics::RubyLevenshtein.distance(puzzle[:target], puzzle[:clue])
        expect(c_clue).to be_within(0.01).of(ruby_clue)
      end
    end
  end

  it 'on average puts the clue ≥2× closer than the distractor (strict Levenshtein)' do
    ratios = PUZZLES.map do |p|
      clue_d       = Phonetics::RubyLevenshtein.distance(p[:target], p[:clue])
      distractor_d = Phonetics::RubyLevenshtein.distance(p[:target], p[:distractor])
      next nil if clue_d.zero?

      distractor_d / clue_d
    end.compact
    mean_ratio = ratios.sum / ratios.size
    expect(mean_ratio).to be > 2.0
  end

  describe 'using the listener-confusion metric' do
    PUZZLES.each do |puzzle|
      it "ranks #{puzzle[:clue_phrase].inspect} closer to #{puzzle[:label].inspect} than the distractor" do
        clue_d       = Phonetics::Confusion.distance(puzzle[:target], puzzle[:clue])
        distractor_d = Phonetics::Confusion.distance(puzzle[:target], puzzle[:distractor])
        expect(clue_d).to be < distractor_d
      end
    end

    it 'beats strict Levenshtein on mean discrimination ratio' do
      strict_ratios = PUZZLES.map do |p|
        cl = Phonetics::RubyLevenshtein.distance(p[:target], p[:clue])
        dl = Phonetics::RubyLevenshtein.distance(p[:target], p[:distractor])
        next nil if cl.zero?

        dl / cl
      end.compact

      conf_ratios = PUZZLES.map do |p|
        cl = Phonetics::Confusion.distance(p[:target], p[:clue])
        dl = Phonetics::Confusion.distance(p[:target], p[:distractor])
        next nil if cl.zero?

        dl / cl
      end.compact

      mean_strict = strict_ratios.sum / strict_ratios.size
      mean_conf   = conf_ratios.sum   / conf_ratios.size
      expect(mean_conf).to be > mean_strict
    end

    it 'achieves a minimum (worst-case) ratio above 1.2 across all puzzles' do
      # The strict metric bottoms out at ~1.05x (the Need-a-Coffee case).
      # Confusion lifts the worst case to ≥1.2x.
      ratios = PUZZLES.map do |p|
        cl = Phonetics::Confusion.distance(p[:target], p[:clue])
        dl = Phonetics::Confusion.distance(p[:target], p[:distractor])
        next nil if cl.zero?

        dl / cl
      end.compact
      expect(ratios.min).to be > 1.2
    end
  end
end
