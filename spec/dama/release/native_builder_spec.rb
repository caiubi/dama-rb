require "spec_helper"
require "tmpdir"

RSpec.describe Dama::Release::NativeBuilder do
  describe "#build" do
    it "runs cargo build --release and returns the library path" do
      Dir.mktmpdir do |_dir|
        builder = described_class.new

        allow(builder).to receive(:system).and_return(true)

        result = builder.build

        expect(result).to match(/libdama_native\.dylib$/)
        expect(builder).to have_received(:system).with(
          hash_including("PATH"),
          "cargo build --release",
          chdir: described_class::RUST_CRATE_PATH,
        )
      end
    end

    it "raises when cargo build fails" do
      Dir.mktmpdir do |_dir|
        builder = described_class.new

        allow(builder).to receive(:system).and_return(false)

        expect { builder.build }.to raise_error(RuntimeError, /Command failed/)
      end
    end
  end

  describe "#library_path" do
    it "returns .dylib on darwin" do
      stub_const("RUBY_PLATFORM", "arm64-darwin24")
      builder = described_class.new

      expect(builder.library_path).to end_with("libdama_native.dylib")
    end

    it "returns .so on linux" do
      stub_const("RUBY_PLATFORM", "x86_64-linux")
      builder = described_class.new

      expect(builder.library_path).to end_with("libdama_native.so")
    end

    it "returns .dll on windows" do
      stub_const("RUBY_PLATFORM", "x64-mingw-ucrt")
      builder = described_class.new

      expect(builder.library_path).to end_with("libdama_native.dll")
    end

    it "points to ext/dama_native/target/release/" do
      builder = described_class.new

      expect(builder.library_path).to include("ext/dama_native/target/release/")
    end
  end
end
