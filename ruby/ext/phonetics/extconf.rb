# frozen_string_literal: true

# Build the Rust-backed native extension that replaces the previous
# hand-written C codegen.
#
# rb_sys/mkmf generates a Makefile that invokes `cargo rustc` against
# the Cargo.toml sibling to this file. That crate is a workspace
# member of <repo>/rust/Cargo.toml — the workspace lints, profile, and
# version come from there, but the build pipeline that produces the
# Ruby-loadable cdylib lives here where conventional gem tooling
# expects it.
require 'mkmf'
require 'rb_sys/mkmf'

create_rust_makefile('phonetics/phonetics_ruby') do |r|
  r.profile = :release
end
