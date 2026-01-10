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
    run at native speed.
  DESC

  spec.homepage = "https://github.com/caiubi/dama-rb"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.4"

  spec.metadata = {
    "rubygems_mfa_required" => "true",
    "homepage_uri" => spec.homepage,
    "source_code_uri" => "https://github.com/caiubi/dama-rb",
  }

  spec.files = Dir[
    "lib/**/*.rb",
    "README.md",
    "LICENSE",
  ]

  spec.add_dependency "zeitwerk", "~> 2.7"
end
