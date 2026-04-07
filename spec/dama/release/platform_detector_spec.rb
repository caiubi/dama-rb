require "spec_helper"

RSpec.describe Dama::Release::PlatformDetector do
  describe ".detect" do
    it "returns :macos on darwin platforms" do
      stub_const("RUBY_PLATFORM", "arm64-darwin24")

      expect(described_class.detect).to eq(:macos)
    end

    it "returns :linux on linux platforms" do
      stub_const("RUBY_PLATFORM", "x86_64-linux")

      expect(described_class.detect).to eq(:linux)
    end

    it "returns :windows on mingw platforms" do
      stub_const("RUBY_PLATFORM", "x64-mingw-ucrt")

      expect(described_class.detect).to eq(:windows)
    end

    it "returns :windows on mswin platforms" do
      stub_const("RUBY_PLATFORM", "x64-mswin64_140")

      expect(described_class.detect).to eq(:windows)
    end

    it "raises a descriptive error for unrecognized platforms" do
      stub_const("RUBY_PLATFORM", "unknown-bsd")

      expect { described_class.detect }.to raise_error(
        Dama::Release::PlatformDetector::UnsupportedPlatformError,
        "Unsupported platform: unknown-bsd",
      )
    end
  end
end
