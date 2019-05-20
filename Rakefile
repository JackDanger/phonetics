require "bundler/gem_tasks"
require "rake/extensiontask"
require "rspec/core/rake_task"

Rake::ExtensionTask.new("c_levenshtein") do |extension|
  extension.ext_dir = "ext/c_levenshtein"
  extension.lib_dir = "lib/phonetics"
end


RSpec::Core::RakeTask.new(:spec)

task :default => :spec
