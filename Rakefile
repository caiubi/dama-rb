require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

namespace :native do
  desc "Build the Rust native extension (release mode)"
  task :build do
    Dir.chdir("ext/dama_native") do
      sh "cargo build --release"
    end
  end

  desc "Run Rust tests"
  task :test do
    Dir.chdir("ext/dama_native") do
      sh "cargo test -- --test-threads=1"
    end
  end
end

task spec: "native:build"
task default: :spec
