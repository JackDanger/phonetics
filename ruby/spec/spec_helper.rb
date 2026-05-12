# frozen_string_literal: true

begin
  require 'bundler/setup'
rescue LoadError, StandardError
  # Allow the suite to run on Ruby versions where bundler/setup is unavailable
  # or its lock can't be satisfied; the lib only depends on stdlib + a built C
  # extension that we load relatively.
  $LOAD_PATH.unshift File.expand_path('../lib', __dir__)
end
require 'phonetics'
require_relative 'support/levenshtein_shared_example'

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
