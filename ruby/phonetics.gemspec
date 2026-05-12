# frozen_string_literal: true

require_relative 'lib/phonetics/version'

Gem::Specification.new do |spec|
  spec.name          = 'phonetics'
  spec.version       = Phonetics::VERSION
  spec.authors       = ['Jack Danger']
  spec.email         = ['github@jackcanty.com']

  spec.summary       = 'IPA-based phonetic distance: strict edit distance, listener-confusion distance, and per-phoneme acoustic and perceptual scoring.'
  spec.description   = <<~DESC
    Tools for working with the International Phonetic Alphabet. Two-tier
    distance API — strict acoustic and listener-perception — backed by a
    Rust core compiled in via Magnus. Calibrated against Mad Gab puzzle
    data and English speech-perception literature.
  DESC
  spec.homepage      = 'https://github.com/JackDanger/phonetics'
  spec.license       = 'MIT'

  spec.required_ruby_version = '>= 3.0'
  spec.required_rubygems_version = '>= 3.3.11'

  spec.metadata['homepage_uri']    = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage

  spec.extensions = ['ext/phonetics/extconf.rb']

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject do |f|
      f.match(%r{\A(test|spec|features)/}) ||
        f.match(%r{\Aext/phonetics/(target|Cargo.lock|Makefile)})
    end
  end
  # Ship the Rust core as part of the gem so a `gem install` doesn't
  # need a separate workspace checkout to find phonetics/.
  rust_core = Dir[File.expand_path('../rust/phonetics/**/*', __dir__)].reject do |p|
    p.include?('/target/') || p.end_with?('Cargo.lock')
  end
  spec.files += rust_core.map { |p| Pathname.new(p).relative_path_from(Pathname.new(File.expand_path('..', __dir__))).to_s }

  spec.require_paths = ['lib']

  spec.add_dependency 'rb_sys', '~> 0.9'

  spec.add_development_dependency 'bundler'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rake-compiler'
  spec.add_development_dependency 'rspec'
  spec.add_development_dependency 'rubocop'
end
