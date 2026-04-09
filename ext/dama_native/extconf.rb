#!/usr/bin/env ruby
# frozen_string_literal: true

# Compiles the Rust cdylib native extension during `gem install`.
# The compiled shared library is placed in lib/dama/native/ where
# FfiBindings can discover it at runtime.

require "fileutils"

CARGO = ENV.fetch("CARGO", "cargo")

def verify_rust_toolchain!
  return if system(CARGO, "--version", out: File::NULL, err: File::NULL)

  abort <<~MSG

    ┌─────────────────────────────────────────────────────┐
    │ Rust toolchain not found.                           │
    │                                                     │
    │ dama requires Rust to compile its native renderer.  │
    │ Install Rust: https://rustup.rs                     │
    └─────────────────────────────────────────────────────┘

  MSG
end

LIBRARY_EXTENSIONS = {
  "darwin" => "dylib",
  "linux" => "so",
  "mingw" => "dll",
  "mswin" => "dll",
}.freeze

def library_extension
  platform_key = LIBRARY_EXTENSIONS.keys.detect { |k| RUBY_PLATFORM.include?(k) }
  LIBRARY_EXTENSIONS.fetch(platform_key) do
    abort "Unsupported platform: #{RUBY_PLATFORM}"
  end
end

def cargo_build!
  puts "=== Compiling dama native extension (this may take a few minutes) ==="
  Dir.chdir(__dir__) do
    success = system(CARGO, "build", "--release")
    abort "cargo build failed" unless success
  end
end

def install_library!
  ext = library_extension
  source = File.join(__dir__, "target", "release", "libdama_native.#{ext}")
  dest_dir = File.expand_path("../../lib/dama/native", __dir__)
  FileUtils.mkdir_p(dest_dir)
  FileUtils.cp(source, dest_dir)
  puts "=== Installed libdama_native.#{ext} to lib/dama/native/ ==="
end

def write_dummy_makefile!
  File.write(File.join(__dir__, "Makefile"), <<~MAKEFILE)
    all:
    \t@echo "dama native extension already compiled"
    install:
    \t@echo "dama native extension already installed"
    clean:
    \t@echo "nothing to clean"
  MAKEFILE
end

verify_rust_toolchain!
cargo_build!
install_library!
write_dummy_makefile!
