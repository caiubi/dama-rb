require "spec_helper"

RSpec.describe "Rust crate wasm32 compilation" do
  it "compiles for wasm32-unknown-unknown without errors" do
    crate_dir = File.join(Dama.root, "ext", "dama_native")

    # Dynamically resolve the active stable toolchain path instead of hardcoding an architecture
    toolchain_bin = Dir.glob(File.join(Dir.home, ".rustup", "toolchains", "stable-*", "bin"))
    rust_path = [File.join(Dir.home, ".cargo", "bin"), *toolchain_bin]
      .select { |d| File.directory?(d) }.join(":")
    env = { "PATH" => "#{rust_path}:#{ENV.fetch("PATH", "")}" }

    cmd = "cd #{crate_dir} && cargo build --release --target wasm32-unknown-unknown 2>&1"
    output = IO.popen(env, cmd) { |io| io.read } # rubocop:disable Style/SymbolProc

    expect($CHILD_STATUS.success?).to be(true), "wasm32 build failed:\n#{output}"
  end
end
