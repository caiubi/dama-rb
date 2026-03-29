require "spec_helper"

RSpec.describe Dama::Cli do
  describe ".run" do
    it "dispatches 'new' to NewProject" do
      allow(Dama::Cli::NewProject).to receive(:run)

      described_class.run(args: ["new"])

      expect(Dama::Cli::NewProject).to have_received(:run)
    end

    it "boots the game for empty args" do
      allow(Dama).to receive(:boot)

      described_class.run(args: [])

      expect(Dama).to have_received(:boot).with(root: Dir.pwd)
    end

    it "boots the game for unrecognized commands, preserving ARGV for Dama.boot" do
      allow(Dama).to receive(:boot)

      described_class.run(args: ["web"])

      expect(Dama).to have_received(:boot).with(root: Dir.pwd)
    end
  end
end
