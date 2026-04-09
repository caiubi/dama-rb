require "spec_helper"
require "tmpdir"
require "zip"

RSpec.describe Dama::Release::Archiver do
  def create_sample_project(dir:)
    source = File.join(dir, "MyGame")
    FileUtils.mkdir_p(File.join(source, "game"))
    File.write(File.join(source, "game", "main.rb"), "class MainScene; end")
    File.write(File.join(source, "config.rb"), "GAME = :test")
    FileUtils.mkdir_p(File.join(source, "assets"))
    File.write(File.join(source, "assets", "sprite.png"), "fake png data")
    source
  end

  describe "#create_macos_zip" do
    it "creates a .zip archive using ditto and returns the archive path" do
      Dir.mktmpdir do |dir|
        source = create_sample_project(dir:)

        archiver = described_class.new(source_path: source)
        allow(archiver).to receive(:system).and_return(true)

        result = archiver.create_macos_zip

        expect(result).to eq("#{source}.zip")
        expect(archiver).to have_received(:system).with(
          "ditto", "-c", "-k", "--sequesterRsrc", "--keepParent",
          source, "#{source}.zip"
        )
      end
    end

    it "removes a previous archive before creating a new one" do
      Dir.mktmpdir do |dir|
        source = create_sample_project(dir:)
        File.write("#{source}.zip", "stale archive")

        archiver = described_class.new(source_path: source)
        allow(archiver).to receive(:system).and_return(true)

        archiver.create_macos_zip

        expect(File.exist?("#{source}.zip")).to be(false)
      end
    end

    it "raises when ditto fails" do
      Dir.mktmpdir do |dir|
        source = create_sample_project(dir:)

        archiver = described_class.new(source_path: source)
        allow(archiver).to receive(:system).and_return(false)

        expect { archiver.create_macos_zip }.to raise_error(RuntimeError, /ditto failed/)
      end
    end
  end

  describe "#create_tar_gz" do
    it "creates a .tar.gz archive and returns the archive path" do
      Dir.mktmpdir do |dir|
        source = create_sample_project(dir:)

        result = described_class.new(source_path: source).create_tar_gz

        expect(result).to eq("#{source}.tar.gz")
        expect(File.exist?(result)).to be(true)
        expect(File.size(result)).to be > 0
      end
    end

    it "includes all files with correct relative paths" do
      require "rubygems/package"

      Dir.mktmpdir do |dir|
        source = create_sample_project(dir:)

        archive_path = described_class.new(source_path: source).create_tar_gz

        entries = []
        File.open(archive_path, "rb") do |file|
          Zlib::GzipReader.wrap(file) do |gz|
            Gem::Package::TarReader.new(gz).each { |entry| entries << entry.full_name }
          end
        end

        expect(entries).to include("MyGame/config.rb", "MyGame/game/main.rb", "MyGame/assets/sprite.png")
      end
    end

    it "removes a previous archive before creating" do
      Dir.mktmpdir do |dir|
        source = create_sample_project(dir:)
        File.write("#{source}.tar.gz", "stale")

        described_class.new(source_path: source).create_tar_gz

        expect(File.size("#{source}.tar.gz")).not_to eq(5)
      end
    end
  end

  describe "#create_zip" do
    it "creates a .zip archive and returns the archive path" do
      Dir.mktmpdir do |dir|
        source = create_sample_project(dir:)

        result = described_class.new(source_path: source).create_zip

        expect(result).to eq("#{source}.zip")
        expect(File.exist?(result)).to be(true)
        expect(File.size(result)).to be > 0
      end
    end

    it "includes all files with correct relative paths" do
      Dir.mktmpdir do |dir|
        source = create_sample_project(dir:)

        archive_path = described_class.new(source_path: source).create_zip

        entries = []
        Zip::File.open(archive_path) do |zipfile|
          zipfile.each { |entry| entries << entry.name }
        end

        expect(entries).to include("MyGame/config.rb", "MyGame/game/main.rb", "MyGame/assets/sprite.png")
      end
    end

    it "removes a previous archive before creating" do
      Dir.mktmpdir do |dir|
        source = create_sample_project(dir:)
        File.write("#{source}.zip", "stale")

        described_class.new(source_path: source).create_zip

        expect(File.size("#{source}.zip")).not_to eq(5)
      end
    end
  end
end
