require "spec_helper"

RSpec.describe Dama::Cli do
  describe ".run" do
    it "dispatches 'new' to NewProject" do
      allow(Dama::Cli::NewProject).to receive(:run)

      described_class.run(args: ["new"])

      expect(Dama::Cli::NewProject).to have_received(:run)
    end

    it "dispatches 'release' to Release with remaining args and root" do
      allow(Dama::Cli::Release).to receive(:run)

      described_class.run(args: %w[release web], root: "/my/project")

      expect(Dama::Cli::Release).to have_received(:run).with(args: ["web"], root: "/my/project")
    end

    it "boots the game with root for empty args" do
      allow(Dama).to receive(:boot)

      described_class.run(args: [], root: "/my/project")

      expect(Dama).to have_received(:boot).with(root: "/my/project")
    end

    it "defaults root to Dir.pwd when not provided" do
      allow(Dama).to receive(:boot)

      described_class.run(args: [])

      expect(Dama).to have_received(:boot).with(root: Dir.pwd)
    end

    it "boots the game for unrecognized commands, preserving ARGV for Dama.boot" do
      allow(Dama).to receive(:boot)

      described_class.run(args: ["web"], root: "/my/project")

      expect(Dama).to have_received(:boot).with(root: "/my/project")
    end
  end
end
