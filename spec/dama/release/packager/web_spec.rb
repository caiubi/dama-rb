require "spec_helper"
require "tmpdir"

RSpec.describe Dama::Release::Packager::Web do
  describe "#package" do
    def stub_archiver
      archiver = instance_double(Dama::Release::Archiver, create_zip: "fake.zip")
      allow(Dama::Release::Archiver).to receive(:new).and_return(archiver)
      archiver
    end

    it "delegates to WebBuilder and copies dist/ to release/web/" do
      Dir.mktmpdir do |dir|
        dist_dir = File.join(dir, "dist")
        FileUtils.mkdir_p(dist_dir)
        File.write(File.join(dist_dir, "index.html"), "<html>game</html>")
        File.write(File.join(dist_dir, "game.wasm"), "fake wasm")

        builder = instance_double(Dama::WebBuilder, build: nil)
        allow(Dama::WebBuilder).to receive(:new).with(project_root: dir).and_return(builder)
        stub_archiver

        described_class.new(project_root: dir).package

        release_dir = File.join(dir, "release", "web")
        expect(File.directory?(release_dir)).to be(true)
        expect(File.read(File.join(release_dir, "index.html"))).to eq("<html>game</html>")
        expect(File.read(File.join(release_dir, "game.wasm"))).to eq("fake wasm")
      end
    end

    it "cleans previous release/web/ before copying" do
      Dir.mktmpdir do |dir|
        dist_dir = File.join(dir, "dist")
        FileUtils.mkdir_p(dist_dir)
        File.write(File.join(dist_dir, "index.html"), "<html>new</html>")

        release_dir = File.join(dir, "release", "web")
        FileUtils.mkdir_p(release_dir)
        File.write(File.join(release_dir, "stale.txt"), "old content")

        builder = instance_double(Dama::WebBuilder, build: nil)
        allow(Dama::WebBuilder).to receive(:new).and_return(builder)
        stub_archiver

        described_class.new(project_root: dir).package

        expect(File.exist?(File.join(release_dir, "stale.txt"))).to be(false)
        expect(File.read(File.join(release_dir, "index.html"))).to eq("<html>new</html>")
      end
    end

    it "creates a zip archive of the web release" do
      Dir.mktmpdir do |dir|
        dist_dir = File.join(dir, "dist")
        FileUtils.mkdir_p(dist_dir)
        File.write(File.join(dist_dir, "index.html"), "<html/>")

        builder = instance_double(Dama::WebBuilder, build: nil)
        allow(Dama::WebBuilder).to receive(:new).and_return(builder)
        archiver = stub_archiver

        described_class.new(project_root: dir).package

        release_dir = File.join(dir, "release", "web")
        expect(Dama::Release::Archiver).to have_received(:new).with(source_path: release_dir)
        expect(archiver).to have_received(:create_zip)
      end
    end
  end
end
