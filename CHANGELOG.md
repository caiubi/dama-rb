# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2026-04-06

### Added

- Ruby DSL for components, nodes, scenes, and a declarative scene graph
- Rust/wgpu rendering backend (Metal, Vulkan, DX12, WebGPU)
- Native (macOS, Linux, Windows) and web (ruby.wasm) support
- Drawing primitives: rect, circle, triangle, text, sprite
- Custom WGSL fragment shader support
- Physics engine with AABB and circle collision detection
- Audio playback (WAV, Vorbis, MP3) via rodio
- Camera system with viewport transformation and zoom
- Tween and animation system with easing functions
- Scene management with compose/enter/update lifecycle
- Auto-discovery and dependency-ordered loading of game files
- Headless rendering mode for testing and screenshots
- HiDPI/Retina display support
- Examples: checkers, demo, breakout
