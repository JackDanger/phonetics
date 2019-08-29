require 'bundler/gem_tasks'
require 'rake/extensiontask'
require 'rspec/core/rake_task'

Rake::ExtensionTask.new('c_levenshtein') do |extension|
  extension.ext_dir = 'ext/c_levenshtein'
  extension.lib_dir = 'lib/phonetics'
end

PHONETIC_COST_C_EXTENSION = File.expand_path('ext/c_levenshtein/phonetic_cost.c', __dir__)

namespace :compile do
  desc 'Write phonetic_cost.c using Phonetic values'
  task :phonetic_cost do
    require_relative './lib/phonetics'
    file = File.open(PHONETIC_COST_C_EXTENSION, 'w')
    Phonetics.generate_phonetic_cost_c_code(file)
    puts "Wrote #{PHONETIC_COST_C_EXTENSION}"
  end
end
task compile: 'compile:phonetic_cost'

RSpec::Core::RakeTask.new(:spec)

task :default => :spec
