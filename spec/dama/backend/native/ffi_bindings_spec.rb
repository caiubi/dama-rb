require "spec_helper"

RSpec.describe Dama::Backend::Native::FfiBindings do
  describe ".library_path" do
    it "returns ENV['DAMA_NATIVE_LIB'] when set" do
      allow(ENV).to receive(:key?).with("DAMA_NATIVE_LIB").and_return(true)
      allow(ENV).to receive(:fetch).with("DAMA_NATIVE_LIB").and_return("/custom/path/libdama.dylib")

      expect(described_class.library_path).to eq("/custom/path/libdama.dylib")
    end

    it "returns the Cargo build output path when ENV is not set" do
      allow(ENV).to receive(:key?).with("DAMA_NATIVE_LIB").and_return(false)

      expect(described_class.library_path).to include("ext/dama_native/target/release/libdama_native")
    end

    it "uses the platform-appropriate extension in development mode" do
      allow(ENV).to receive(:key?).with("DAMA_NATIVE_LIB").and_return(false)
      stub_const("RUBY_PLATFORM", "arm64-darwin24")

      expect(described_class.library_path).to end_with(".dylib")
    end
  end

  describe "LIBRARY_EXTENSIONS" do
    it "maps platform keys to shared library extensions" do
      expect(described_class::LIBRARY_EXTENSIONS).to eq(
        "darwin" => "dylib",
        "linux" => "so",
        "mingw" => "dll",
        "mswin" => "dll",
      )
    end
  end
end
