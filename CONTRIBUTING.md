# Contributing to dama-rb

Thank you for your interest in contributing to dama-rb!

## Development Setup

### Prerequisites

- Ruby 3.4+
- Rust (stable, via [rustup](https://rustup.rs/))
- wasm-bindgen-cli (`cargo install wasm-bindgen-cli`) — for web builds only
- npm — for downloading ruby.wasm base binary (web builds only)

### Getting Started

```bash
git clone https://github.com/caiubi/dama-rb
cd dama-rb
bundle install
```

### Running Tests

```bash
bundle exec rspec              # Ruby specs (auto-builds Rust extension)
bundle exec rubocop            # Ruby linting
cd ext/dama_native && cargo test     # Rust tests
cd ext/dama_native && cargo clippy   # Rust linting
```

### Running Examples

```bash
cd examples/checkers && bin/dama       # Native
cd examples/checkers && bin/dama web   # Browser (WebGPU)
```

## Code Style

This project follows strict Object-Oriented Design principles:

- **SOLID principles** — especially Single Responsibility and Open/Closed
- **Composition over inheritance**
- **Dependency injection**
- **Polymorphism over conditionals** — dispatch via Hash lookup or factory, not `if`/`case`
- **Keyword arguments** over positional
- **Double quotes** for strings
- **100% test coverage** — write specs before code (TDD)
- **RSpec** for all tests

Run `bundle exec rubocop` before submitting to ensure style compliance.

## Submitting Changes

1. Fork the repository
2. Create a feature branch (`git checkout -b my-feature`)
3. Write tests first, then implementation
4. Ensure all tests pass and coverage remains at 100%
5. Run RuboCop and Clippy with zero warnings
6. Submit a pull request with a clear description

## Architecture

```
Ruby DSL (your game code)
    ↓
Dama Engine (Ruby)
    ↓ FFI / JS bridge
Rust Backend (wgpu)
    ↓
GPU (Metal / Vulkan / WebGPU)
```

- **Ruby** owns the game loop, scene graph, components, and input
- **Rust** owns window management (winit), GPU rendering (wgpu), text (glyphon), and audio (rodio)
- **Native**: Ruby calls Rust via FFI (cdylib)
- **Web**: Ruby runs in ruby.wasm, calls Rust WASM via JS bridge

## Reporting Bugs

Open an issue at https://github.com/caiubi/dama-rb/issues with:

- Ruby and Rust versions
- Operating system
- Steps to reproduce
- Expected vs actual behavior
