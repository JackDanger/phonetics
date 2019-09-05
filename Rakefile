# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rake/extensiontask'
require 'rspec/core/rake_task'
require 'rubocop/rake_task'

EXT_PATH = 'ext/c_levenshtein'

Rake::ExtensionTask.new('c_levenshtein') do |extension|
  extension.ext_dir = EXT_PATH
  extension.lib_dir = 'lib/phonetics'
end

PHONETIC_COST_C_EXTENSION = File.join(EXT_PATH, 'phonetic_cost.c')
NEXT_PHONEME_LENGTH_C_EXTENSION = File.join(EXT_PATH, 'next_phoneme_length.c')

require_relative './lib/phonetics/code_generator'

desc 'Write phonetic_cost.c using Phonetic values'
task PHONETIC_COST_C_EXTENSION do
  file = File.open(PHONETIC_COST_C_EXTENSION, 'w')
  Phonetics::CodeGenerator.new(file).generate_phonetic_cost_c_code
  puts "Wrote #{PHONETIC_COST_C_EXTENSION}"
end

desc 'Write phonemes.c using a lookup table of byte arrays'
task NEXT_PHONEME_LENGTH_C_EXTENSION do
  file = File.open(NEXT_PHONEME_LENGTH_C_EXTENSION, 'w')
  Phonetics::CodeGenerator.new(file).generate_next_phoneme_length_c_code
  puts "Wrote #{NEXT_PHONEME_LENGTH_C_EXTENSION}"
end

task compile: PHONETIC_COST_C_EXTENSION
task compile: NEXT_PHONEME_LENGTH_C_EXTENSION

RSpec::Core::RakeTask.new(:spec)

RuboCop::RakeTask.new

task default: [:compile, :rubocop, :spec]
