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

namespace :gem do
  desc "Build source gem (platform: ruby, requires Rust to install)"
  task :source do
    sh "gem build dama.gemspec"
  end

  desc "Build platform gem for current OS/arch (bundles pre-compiled binary)"
  task :native do
    ruby "script/build_platform_gem.rb"
  end
end

task spec: "native:build"
task default: :spec
