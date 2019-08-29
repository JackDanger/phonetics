# frozen_string_literal: true

# Loads mkmf which is used to make makefiles for Ruby extensions
require "mkmf"

# The destination
dir_config("phonetics/levenshtein")

# Do the work
create_makefile("phonetics/c_levenshtein")
