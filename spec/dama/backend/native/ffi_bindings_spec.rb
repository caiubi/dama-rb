require "spec_helper"

RSpec.describe Dama::Backend::Native::FfiBindings do
  describe ".library_path" do
    let(:filename) { described_class.library_filename }
    let(:gem_path) { File.expand_path("../../../../lib/dama/native/#{filename}", __dir__) }
    let(:dev_path) { File.expand_path("../../../../ext/dama_native/target/release/#{filename}", __dir__) }

    it "returns ENV['DAMA_NATIVE_LIB'] when set and the file exists" do
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:fetch).with("DAMA_NATIVE_LIB", nil).and_return("/custom/path/libdama.dylib")
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with("/custom/path/libdama.dylib").and_return(true)

      expect(described_class.library_path).to eq("/custom/path/libdama.dylib")
    end

    it "falls back to the development path when ENV and gem path are absent" do
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:fetch).with("DAMA_NATIVE_LIB", nil).and_return(nil)
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with(gem_path).and_return(false)
      allow(File).to receive(:exist?).with(dev_path).and_return(true)

      expect(described_class.library_path).to eq(dev_path)
    end

    it "prefers the gem-installed path over the development path" do
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:fetch).with("DAMA_NATIVE_LIB", nil).and_return(nil)
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

    it "uses the platform-appropriate filename" do
      platform_key = described_class::LIBRARY_EXTENSIONS.keys.detect { |k| RUBY_PLATFORM.include?(k) }
      extension = described_class::LIBRARY_EXTENSIONS.fetch(platform_key)

      expect(filename).to end_with(".#{extension}")
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

  describe "LIBRARY_PREFIXES" do
    it "uses lib prefix on Unix and no prefix on Windows" do
      expect(described_class::LIBRARY_PREFIXES).to eq(
        "darwin" => "lib",
        "linux" => "lib",
        "mingw" => "",
        "mswin" => "",
      )
    end
  end
end
