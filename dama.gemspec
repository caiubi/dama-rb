require_relative "lib/dama/version"

Gem::Specification.new do |spec|
  spec.name = "dama"
  spec.version = Dama::VERSION
  spec.authors = ["Caiubi Fonseca"]
  spec.email = ["caiubi@icloud.com"]

  spec.summary = "A cross-platform 2D game engine with a Ruby DSL and Rust rendering backend"
  spec.description = <<~DESC
    dama-rb is a 2D game engine that lets you write games in Ruby using a
    declarative DSL. The engine renders via a Rust/wgpu backend (Metal, Vulkan,
    DX12, WebGPU), so your game code is pure Ruby while GPU-accelerated graphics
    run at native speed. Games can run natively or in the browser via ruby.wasm.
  DESC

  spec.homepage = "https://github.com/caiubi/dama-rb"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.4"

  spec.metadata = {
    "rubygems_mfa_required" => "true",
    "homepage_uri" => spec.homepage,
    "source_code_uri" => "https://github.com/caiubi/dama-rb",
    "bug_tracker_uri" => "https://github.com/caiubi/dama-rb/issues",
    "changelog_uri" => "https://github.com/caiubi/dama-rb/blob/main/CHANGELOG.md",
  }

  spec.bindir = "exe"
  spec.executables = ["dama"]

  spec.files = Dir[
    "lib/**/*.rb",
    "lib/**/*.html",
    "exe/*",
    "ext/**/*.rs",
    "ext/**/Cargo.toml",
    "ext/**/Cargo.lock",
    "ext/**/.cargo/config.toml",
    "dama-logo.svg",
    "README.md",
    "LICENSE",
  ]

  spec.add_dependency "ffi", "~> 1.17"
  spec.add_dependency "ruby_wasm", "~> 2.8"
  spec.add_dependency "webrick", "~> 1.9"
  spec.add_dependency "zeitwerk", "~> 2.7"
end
