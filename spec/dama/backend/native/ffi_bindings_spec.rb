require "spec_helper"

RSpec.describe Dama::Backend::Native::FfiBindings do
  describe ".library_path" do
    it "returns ENV['DAMA_NATIVE_LIB'] when set and the file exists" do
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:fetch).with("DAMA_NATIVE_LIB", nil).and_return("/custom/path/libdama.dylib")
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with("/custom/path/libdama.dylib").and_return(true)

      expect(described_class.library_path).to eq("/custom/path/libdama.dylib")
    end

    it "falls back to the development path when ENV is not set" do
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:fetch).with("DAMA_NATIVE_LIB", nil).and_return(nil)

      expect(described_class.library_path).to include("ext/dama_native/target/release/libdama_native")
    end

    it "prefers the gem-installed path over the development path" do
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:fetch).with("DAMA_NATIVE_LIB", nil).and_return(nil)

      gem_path = File.expand_path("../../../../lib/dama/native/libdama_native.dylib", __dir__)
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with(gem_path).and_return(true)

      expect(described_class.library_path).to eq(gem_path)
    end

    it "raises when no library is found anywhere" do
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:fetch).with("DAMA_NATIVE_LIB", nil).and_return(nil)
      allow(File).to receive(:exist?).and_return(false)

      expect { described_class.library_path }.to raise_error(RuntimeError, /native library not found/)
    end

    it "uses the platform-appropriate extension" do
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:fetch).with("DAMA_NATIVE_LIB", nil).and_return(nil)
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
