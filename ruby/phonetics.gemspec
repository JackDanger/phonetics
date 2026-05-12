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

  spec.extensions = ['ext/phonetics_ruby/extconf.rb']

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    tracked = `git ls-files -z`.split("\x0").reject do |f|
      f.match(%r{\A(test|spec|features)/}) ||
        f.match(%r{\Aext/phonetics_ruby/(target|Cargo.lock|Makefile)})
    end
    # The vendored Rust core isn't tracked in git (it's a build
    # artifact populated by `rake vendor_rust`), but it IS shipped
    # in the .gem tarball so end users don't need the source
    # workspace to compile the extension.
    vendor = Dir.glob('ext/phonetics_ruby/vendor/**/*', File::FNM_DOTMATCH).reject do |p|
      File.directory?(p) ||
        p.include?('/target/') ||
        p.end_with?('Cargo.lock', '/.', '/..')
    end
    (tracked + vendor).uniq.sort
  end

  spec.require_paths = ['lib']

  spec.add_dependency 'rb_sys', '~> 0.9'

  spec.add_development_dependency 'bundler'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rake-compiler'
  spec.add_development_dependency 'rspec'
  spec.add_development_dependency 'rubocop'
end
