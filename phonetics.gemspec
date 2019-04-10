Gem::Specification.new do |spec|
  spec.name          = "phonetics"
  spec.version       = File.read(File.join(File.dirname(__FILE__), './VERSION'))
  spec.authors       = ["Jack Danger"]
  spec.email         = ["github@jackcanty.com"]

  spec.summary       = %q{tools for linguistic code using the International Phonetic Alphabet}
  spec.description   = %q{tools for linguistic code using the International Phonetic Alphabet}
  spec.homepage      = "https://github.com/JackDanger/phonetics"
  spec.license       = "MIT"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.16"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec", "~> 3.0"
end
