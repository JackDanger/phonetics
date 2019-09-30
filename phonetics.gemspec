# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name          = 'phonetics'
  spec.version       = File.read(File.join(File.dirname(__FILE__), './VERSION'))
  spec.authors       = ['Jack Danger']
  spec.email         = ['github@jackcanty.com']

  spec.summary       = 'tools for linguistic code using the International Phonetic Alphabet'
  spec.description   = 'tools for linguistic code using the International Phonetic Alphabet'
  spec.homepage      = 'https://github.com/JackDanger/phonetics'
  spec.license       = 'MIT'

  spec.extensions = ['ext/c_levenshtein/extconf.rb']

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.require_paths = ['lib']

  spec.add_development_dependency 'bundler'
  spec.add_development_dependency 'pry-byebug'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rake-compiler'
  spec.add_development_dependency 'rspec'
  spec.add_development_dependency 'rubocop'
  spec.add_development_dependency 'ruby-prof'
end
