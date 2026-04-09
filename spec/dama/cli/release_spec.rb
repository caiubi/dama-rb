require "spec_helper"
require "tmpdir"

RSpec.describe Dama::Cli::Release do
  describe ".run" do
    it "dispatches to web packager when args contain 'web'" do
      Dir.mktmpdir do |dir|
        packager = instance_double(Dama::Release::Packager::Web, package: nil)
        allow(Dama::Release::Packager::Web).to receive(:new).and_return(packager)

        described_class.run(args: ["web"], root: dir)

        expect(Dama::Release::Packager::Web).to have_received(:new).with(project_root: dir)
        expect(packager).to have_received(:package).with(archive: true)
      end
    end

    it "passes archive: false when --no-archive flag is present" do
      Dir.mktmpdir do |dir|
        packager = instance_double(Dama::Release::Packager::Web, package: nil)
        allow(Dama::Release::Packager::Web).to receive(:new).and_return(packager)

        described_class.run(args: ["web", "--no-archive"], root: dir)

        expect(packager).to have_received(:package).with(archive: false)
      end
    end

    it "dispatches to macOS packager on darwin" do
      stub_const("RUBY_PLATFORM", "arm64-darwin24")

      Dir.mktmpdir do |dir|
        packager = instance_double(Dama::Release::Packager::Macos, package: nil)
        allow(Dama::Release::Packager::Macos).to receive(:new).and_return(packager)

        described_class.run(args: [], root: dir)

        expect(Dama::Release::Packager::Macos).to have_received(:new).with(project_root: dir)
        expect(packager).to have_received(:package).with(archive: true)
      end
    end

    it "dispatches to linux packager on linux" do
      stub_const("RUBY_PLATFORM", "x86_64-linux")

      Dir.mktmpdir do |dir|
        packager = instance_double(Dama::Release::Packager::Linux, package: nil)
        allow(Dama::Release::Packager::Linux).to receive(:new).and_return(packager)

        described_class.run(args: [], root: dir)

        expect(Dama::Release::Packager::Linux).to have_received(:new).with(project_root: dir)
        expect(packager).to have_received(:package).with(archive: true)
      end
    end

    it "dispatches to windows packager on mingw" do
      stub_const("RUBY_PLATFORM", "x64-mingw-ucrt")

      Dir.mktmpdir do |dir|
        packager = instance_double(Dama::Release::Packager::Windows, package: nil)
        allow(Dama::Release::Packager::Windows).to receive(:new).and_return(packager)

        described_class.run(args: [], root: dir)

        expect(Dama::Release::Packager::Windows).to have_received(:new).with(project_root: dir)
        expect(packager).to have_received(:package).with(archive: true)
      end
    end

    it "passes --no-archive to native packagers" do
      stub_const("RUBY_PLATFORM", "arm64-darwin24")

      Dir.mktmpdir do |dir|
        packager = instance_double(Dama::Release::Packager::Macos, package: nil)
        allow(Dama::Release::Packager::Macos).to receive(:new).and_return(packager)

        described_class.run(args: ["--no-archive"], root: dir)

        expect(packager).to have_received(:package).with(archive: false)
      end
    end
  end
end
