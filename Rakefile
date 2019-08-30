# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rake/extensiontask'
require 'rspec/core/rake_task'
require 'rubocop/rake_task'

Rake::ExtensionTask.new('c_levenshtein') do |extension|
  extension.ext_dir = 'ext/c_levenshtein'
  extension.lib_dir = 'lib/phonetics'
end

PHONETIC_COST_C_EXTENSION = File.expand_path('ext/c_levenshtein/phonetic_cost.c', __dir__)
PHONEMES_C_EXTENSION = File.expand_path('ext/c_levenshtein/phonemes.c', __dir__)

require_relative './lib/phonetics/code_generator'

namespace :compile do
  desc 'Write phonetic_cost.c using Phonetic values'
  task :phonetic_cost do
    file = File.open(PHONETIC_COST_C_EXTENSION, 'w')
    Phonetics::CodeGenerator.new(file).generate_phonetic_cost_c_code
    puts "Wrote #{PHONETIC_COST_C_EXTENSION}"
  end

  desc 'Write phonemes.c using a lookup table of byte arrays'
  task :phonemes do
    file = File.open(PHONEMES_C_EXTENSION, 'w')
    Phonetics::CodeGenerator.new(file).generate_next_phoneme_length_c_code
    puts "Wrote #{PHONEMES_C_EXTENSION}"
  end
end
task compile: ['compile:phonemes', 'compile:phonetic_cost']

RSpec::Core::RakeTask.new(:spec)

RuboCop::RakeTask.new

task default: [:compile, :rubocop, :spec]
