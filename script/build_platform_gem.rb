#!/usr/bin/env ruby
# frozen_string_literal: true

# Builds a platform-specific gem that bundles a pre-compiled native library.
# The resulting gem does not require Rust -- users get a ready-to-use binary.
#
# Usage:
#   ruby script/build_platform_gem.rb            # auto-detect current platform
#   ruby script/build_platform_gem.rb arm64-darwin
#   ruby script/build_platform_gem.rb x86_64-linux

require "fileutils"
require "rubygems"
require "rubygems/package"

NATIVE_DIR = File.expand_path("../lib/dama/native", __dir__)
EXT_DIR = File.expand_path("../ext/dama_native", __dir__)

LIBRARY_NAMES = {
  "darwin" => "libdama_native.dylib",
  "linux" => "libdama_native.so",
  "mingw" => "dama_native.dll",
  "mswin" => "dama_native.dll",
}.freeze

def detect_platform
  Gem::Platform.local.to_s
end

def library_filename_for(platform)
  key = LIBRARY_NAMES.keys.detect { |k| platform.include?(k) }
  LIBRARY_NAMES.fetch(key) { abort "Unknown platform: #{platform}" }
end

def build_native_library!
  puts "=== Building native library (release) ==="
  Dir.chdir(EXT_DIR) do
    success = system("cargo", "build", "--release")
    abort "cargo build failed" unless success
  end
end

def copy_library_to_native_dir!(platform)
  filename = library_filename_for(platform)
  source = File.join(EXT_DIR, "target", "release", filename)
  abort "Compiled library not found at #{source}" unless File.exist?(source)

  FileUtils.mkdir_p(NATIVE_DIR)
  FileUtils.cp(source, NATIVE_DIR)
  puts "=== Copied #{filename} to lib/dama/native/ ==="
end

def codesign_if_macos!(platform)
  return unless platform.include?("darwin")

  filename = library_filename_for(platform)
  lib_path = File.join(NATIVE_DIR, filename)
  success = system("codesign", "--sign", "-", "--force", lib_path)
  abort "codesign failed for #{lib_path}" unless success

  puts "=== Ad-hoc signed #{lib_path} ==="
end

def build_platform_gem!(platform)
  gemspec_path = File.expand_path("../dama.gemspec", __dir__)
  spec = Gem::Specification.load(gemspec_path)

  spec.platform = Gem::Platform.new(platform)

  # Platform gems bundle the compiled binary -- no compilation needed
  spec.extensions.clear

  # Remove Rust source files, add compiled binary
  spec.files.reject! { |f| f.start_with?("ext/") }

  filename = library_filename_for(platform)
  native_lib = "lib/dama/native/#{filename}"
  spec.files << native_lib

  puts "=== Building gem: #{spec.full_name} ==="
  package = Gem::Package.build(spec)
  puts "=== Built: #{package} ==="
end

platform = ARGV.first || detect_platform

build_native_library!
copy_library_to_native_dir!(platform)
codesign_if_macos!(platform)
build_platform_gem!(platform)
