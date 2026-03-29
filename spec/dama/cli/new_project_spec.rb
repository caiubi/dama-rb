require "spec_helper"
require "tmpdir"

RSpec.describe Dama::Cli::NewProject do
  describe ".run" do
    it "generates all template files with exact content" do
      Dir.mktmpdir do |dir|
        Dir.chdir(dir) do
          described_class.run

          described_class::TEMPLATES.each do |path, template|
            expect(File.exist?(path)).to be(true), "Expected #{path} to exist"
            expect(File.read(path)).to eq(template.fetch(:content))
          end
        end
      end
    end

    it "creates the assets directory" do
      Dir.mktmpdir do |dir|
        Dir.chdir(dir) do
          described_class.run

          expect(File.directory?("assets")).to be(true)
        end
      end
    end

    it "makes bin/dama executable" do
      Dir.mktmpdir do |dir|
        Dir.chdir(dir) do
          described_class.run

          expect(File.executable?("bin/dama")).to be(true)
        end
      end
    end

    it "sets non-executable files to 0644" do
      Dir.mktmpdir do |dir|
        Dir.chdir(dir) do
          described_class.run

          mode = File.stat("config.rb").mode & 0o777
          expect(mode).to eq(0o644)
        end
      end
    end

    it "skips files that already exist without overwriting" do
      Dir.mktmpdir do |dir|
        Dir.chdir(dir) do
          FileUtils.mkdir_p("bin")
          File.write("config.rb", "my custom config")

          described_class.run

          expect(File.read("config.rb")).to eq("my custom config")
        end
      end
    end

    it "skips the assets directory when it already exists" do
      Dir.mktmpdir do |dir|
        Dir.chdir(dir) do
          FileUtils.mkdir_p("assets")
          File.write("assets/keep.txt", "preserved")

          described_class.run

          expect(File.read("assets/keep.txt")).to eq("preserved")
        end
      end
    end

    it "creates nested directories for template paths" do
      Dir.mktmpdir do |dir|
        Dir.chdir(dir) do
          described_class.run

          expect(File.directory?("game/components")).to be(true)
          expect(File.directory?("game/nodes")).to be(true)
          expect(File.directory?("game/scenes")).to be(true)
        end
      end
    end
  end
end
