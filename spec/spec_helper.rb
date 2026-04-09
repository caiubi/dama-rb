require "simplecov"
SimpleCov.start do
  add_filter "/spec/"
  add_filter "lib/dama/web_builder.rb"
  enable_coverage :branch
  minimum_coverage line: 100, branch: 100
end

require "dama"
require "chunky_png"

# Ensure the Rust native extension is built before running specs.
native_lib = Dama::Backend::Native::FfiBindings.library_path
rust_sources = Dir["#{Dama.root}/ext/dama_native/src/**/*.rs"]
lib_mtime = File.exist?(native_lib) ? File.mtime(native_lib) : Time.at(0)

stale = rust_sources.any? { |src| File.mtime(src) > lib_mtime }

if stale || !File.exist?(native_lib)

  # Ensure cargo is discoverable even when not in shell PATH.
  rust_path = [
    File.join(Dir.home, ".cargo", "bin"),
    *Dir[File.join(Dir.home, ".rustup", "toolchains", "stable-*", "bin")],
  ].select { |d| File.directory?(d) }.join(File::PATH_SEPARATOR)
  env = { "PATH" => "#{rust_path}:#{ENV.fetch("PATH", "")}" }
  system(env, "cd #{Dama.root}/ext/dama_native && cargo build --release", exception: true)
end

Dir["#{__dir__}/support/**/*.rb"].each { |f| require f }

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.order = :random
  Kernel.srand config.seed
end
