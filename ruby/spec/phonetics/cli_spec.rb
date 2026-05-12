# frozen_string_literal: true

require 'json'
require 'open3'

# Integration tests for the phonetics CLI. These deliberately shell out to
# bin/phonetics instead of calling Ruby classes directly: the contract under
# test is the executable's input/output, not the Ruby implementation. A
# reimplementation in Rust (or anything else) that preserves the same CLI
# behavior is automatically validated by these tests.
RSpec.describe 'phonetics CLI' do
  # The path resolves to ruby/bin/phonetics by default. Set the
  # `PHONETICS_BIN` env var to point at any other executable that
  # implements the same CLI contract — that's the whole point of the
  # cross-implementation integration suite.
  PHONETICS_BIN = ENV.fetch('PHONETICS_BIN',
                            File.expand_path('../../bin/phonetics', __dir__))

  def run(*args)
    stdout, stderr, status = Open3.capture3(PHONETICS_BIN, *args)
    [stdout.strip, stderr.strip, status.exitstatus]
  end

  def run_number(*args)
    out, err, status = run(*args)
    raise "phonetics #{args.inspect} failed: #{err}" unless status.zero?

    out.to_f
  end

  # -----------------------------------------------------------------
  # Tier 1: per-phoneme distances
  # -----------------------------------------------------------------
  describe 'phoneme tier' do
    it 'returns 0 for a phoneme against itself (acoustic and perceptual)' do
      expect(run_number('phoneme', 'p', 'p')).to eq(0.0)
      expect(run_number('phoneme-conf', 'p', 'p')).to eq(0.0)
    end

    it 'returns the same value in both tiers for a pair without an overlay entry' do
      # Voicing flips are already at the cheap end of acoustic distance —
      # the overlay doesn't override them because it doesn't have to.
      strict = run_number('phoneme', 'p', 'b')
      perc   = run_number('phoneme-conf', 'p', 'b')
      expect(strict).to be_within(1e-6).of(perc)
    end

    it 'preserves the strict/perceptual split on t-flapping' do
      # /t/ vs the alveolar flap [ɾ]. Acoustically far apart (~0.5);
      # perceptually they're nearly identical for American listeners.
      strict = run_number('phoneme', 't', 'ɾ')
      perc   = run_number('phoneme-conf', 't', 'ɾ')
      expect(strict).to be > 0.4
      expect(perc).to   be < 0.15
    end

    it 'preserves the strict/perceptual split on cot/caught (WCE merger)' do
      strict = run_number('phoneme', 'ɑ', 'ɔ')
      perc   = run_number('phoneme-conf', 'ɑ', 'ɔ')
      expect(strict).to be > 0.15
      expect(perc).to   be < 0.10
    end

    it 'preserves the strict/perceptual split on th-stopping' do
      strict = run_number('phoneme', 'θ', 't')
      perc   = run_number('phoneme-conf', 'θ', 't')
      expect(strict).to be > 0.20
      expect(perc).to   be < strict
    end

    it 'fixes the /l/-/ɹ/ pair that used to be tied at zero' do
      expect(run_number('phoneme', 'l', 'ɹ')).to be > 0.0
    end
  end

  # -----------------------------------------------------------------
  # Tier 2: phrase-level strict Levenshtein
  # -----------------------------------------------------------------
  describe 'strict Levenshtein tier' do
    it 'is zero for identical strings' do
      expect(run_number('distance', 'kæt', 'kæt')).to eq(0.0)
    end

    it 'costs roughly one indel for a single-phoneme deletion at the head' do
      expect(run_number('distance', 'dɪsug', 'ɪsug')).to be_within(0.05).of(1.0)
    end

    it 'costs the phoneme count when one side is empty' do
      # 'kæt' = 3 phonemes, indel cost 1.0 each.
      expect(run_number('distance', 'kæt', '')).to be_within(0.05).of(3.0)
    end

    it 'is the substitution sum for length-aligned pairs' do
      # All four positions substitute; expected ≈ sum of per-phoneme costs.
      total = %w[i z o k].zip(%w[ɪ s u g]).sum { |a, b| run_number('phoneme', a, b) }
      expect(run_number('distance', 'izok', 'ɪsug')).to be_within(0.05).of(total)
    end
  end

  # -----------------------------------------------------------------
  # Tier 3: phrase-level listener confusion
  # -----------------------------------------------------------------
  describe 'confusion tier' do
    it 'is zero for identical strings' do
      expect(run_number('confusion', 'kæt', 'kæt')).to eq(0.0)
    end

    it 'is cheaper than strict Levenshtein on a Mad Gab pair' do
      target = 'ɪtsdʒʌstəstupɪdgeɪm'
      clue   = 'hɪtsdʒʌstɪsduphɪdkeɪm'
      strict = run_number('distance',  target, clue)
      conf   = run_number('confusion', target, clue)
      expect(conf).to be < strict
    end

    it 'discriminates the Mad Gab clue from an unrelated decoy by ≥5x' do
      target = 'ɪtsdʒʌstəstupɪdgeɪm'
      clue   = 'hɪtsdʒʌstɪsduphɪdkeɪm'
      decoy  = 'jɔrmʌðɝwɛrzsneɪkɝz'
      expect(run_number('confusion', target, decoy)).to be > 5 * run_number('confusion', target, clue)
    end

    it 'gives near-zero cost to a moved word boundary' do
      # Same phonemes, boundary repositioned. The pure-phoneme contents
      # are identical; confusion should reflect that.
      a = 'ɪts dʒʌst'
      b = 'ɪt sdʒʌst'
      expect(run_number('confusion', a, b)).to be < 0.05
    end

    it 'gives near-zero cost on a homophone Mad Gab pair' do
      # "Eye Love Ewe" / "I love you" — pure homophone, distance 0.
      expect(run_number('confusion', 'aɪlʌvju', 'aɪlʌvju')).to eq(0.0)
    end
  end

  # -----------------------------------------------------------------
  # Tier 4: normalised similarity
  # -----------------------------------------------------------------
  describe 'similarity tier' do
    it 'is exactly 1.0 for identical strings' do
      expect(run_number('similarity', 'kæt', 'kæt')).to eq(1.0)
    end

    it 'is in [0, 1] for any pair' do
      [
        %w[kæt dɔg],
        %w[ɪtsdʒʌstəstupɪdgeɪm jɔrmʌðɝwɛrzsneɪkɝz],
      ].each do |a, b|
        sim = run_number('similarity', a, b)
        expect(sim).to be >= 0.0
        expect(sim).to be <= 1.0
      end
    end

    it 'puts a Mad Gab clue ≥0.2 above an unrelated decoy' do
      target = 'ɪtsdʒʌstəstupɪdgeɪm'
      clue   = 'hɪtsdʒʌstɪsduphɪdkeɪm'
      decoy  = 'jɔrmʌðɝwɛrzsneɪkɝz'
      delta = run_number('similarity', target, clue) - run_number('similarity', target, decoy)
      expect(delta).to be >= 0.2
    end
  end

  # -----------------------------------------------------------------
  # Tier 5: tokenisation
  # -----------------------------------------------------------------
  describe 'tokenisation' do
    it 'splits an IPA string into one phoneme per line' do
      stdout, _, status = run('tokenize', 'kæt')
      expect(status).to eq(0)
      expect(stdout.split("\n")).to eq(%w[k æ t])
    end

    it 'recognises diphthongs as atomic phonemes' do
      stdout, _, _ = run('tokenize', 'kɑɪt')
      expect(stdout.split("\n")).to eq(%w[k ɑɪ t])
    end

    it 'recognises affricates as atomic phonemes' do
      stdout, _, _ = run('tokenize', 'dʒʌdʒ')
      expect(stdout.split("\n")).to eq(%w[dʒ ʌ dʒ])
    end

    it 'absorbs aspiration onto the preceding consonant' do
      stdout, _, _ = run('tokenize', 'pʰɪt')
      expect(stdout.split("\n")).to eq(%w[pʰ ɪ t])
    end

    it 'omits whitespace by default' do
      stdout, _, _ = run('tokenize', 'kæt dɔg')
      expect(stdout.split("\n")).to eq(%w[k æ t d ɔ g])
    end

    it 'emits the boundary token with --boundaries' do
      stdout, _, _ = run('tokenize', '--boundaries', 'kæt dɔg')
      expect(stdout.split("\n")).to eq(['k', 'æ', 't', '#', 'd', 'ɔ', 'g'])
    end
  end

  # -----------------------------------------------------------------
  # Structured output and error handling
  # -----------------------------------------------------------------
  describe 'JSON output' do
    it 'wraps numeric results in {"value": ...}' do
      stdout, _, status = run('--json', 'confusion', 'kæt', 'kʌt')
      expect(status).to eq(0)
      parsed = JSON.parse(stdout)
      expect(parsed).to have_key('value')
      expect(parsed['value']).to be > 0.0
    end

    it 'wraps token lists in {"tokens": [...]}' do
      stdout, _, status = run('--json', 'tokenize', 'kæt')
      expect(status).to eq(0)
      parsed = JSON.parse(stdout)
      expect(parsed).to eq('tokens' => %w[k æ t])
    end
  end

  describe 'error handling' do
    it 'exits non-zero on missing arguments' do
      _, _, status = run('distance', 'only-one-arg')
      expect(status).not_to eq(0)
    end

    it 'exits non-zero on unknown subcommand' do
      _, stderr, status = run('asdf', 'a', 'b')
      expect(status).not_to eq(0)
      expect(stderr).not_to be_empty
    end

    it 'prints usage on --help with zero exit' do
      stdout, _, status = run('--help')
      expect(status).to eq(0)
      expect(stdout).to match(/Usage: phonetics/)
    end
  end

  # -----------------------------------------------------------------
  # Whole-stack Mad Gab regression
  # -----------------------------------------------------------------
  describe 'Mad Gab basket via the CLI' do
    # Same puzzles as madgab_spec.rb but driven entirely through the
    # executable. If we ever ship a Rust binary, this is the suite that
    # gates parity.
    PUZZLES = [
      ['ɪtsdʒʌstəstupɪdgeɪm',  'hɪtsdʒʌstɪsduphɪdkeɪm', 'jɔrmʌðɝwɛrzsneɪkɝz'],
      ['æpəlpaɪ',              'eɪppʊlpaɪ',             'rɑkiroʊd'],
      ['məʃingʌn',             'mʌʃʃingʌm',             'maʊntɪnrʌn'],
      ['mæstɝbeɪkɝ',           'mæsstɝbeɪkhɝ',          'lɔstɪnðədɑrk'],
      ['sænwɪtʃ',              'sændwɛdʒ',              'lɛmənslaɪs'],
    ].freeze

    PUZZLES.each_with_index do |(target, clue, decoy), i|
      it "ranks puzzle ##{i + 1} clue closer than decoy under confusion" do
        clue_d  = run_number('confusion', target, clue)
        decoy_d = run_number('confusion', target, decoy)
        expect(clue_d).to be < decoy_d
      end
    end
  end
end
