require "spec_helper"
require "tmpdir"

RSpec.describe Dama::Release::GameFileCopier do
  describe "#copy" do
    it "copies game/, config.rb, and assets/ to the destination" do
      Dir.mktmpdir do |root|
        project = File.join(root, "project")
        dest = File.join(root, "release")
        FileUtils.mkdir_p([project, dest])

        FileUtils.mkdir_p(File.join(project, "game", "scenes"))
        File.write(File.join(project, "game", "scenes", "main.rb"), "class MainScene; end")
        File.write(File.join(project, "config.rb"), "GAME = Dama::Game.new {}")
        FileUtils.mkdir_p(File.join(project, "assets"))
        File.write(File.join(project, "assets", "sprite.png"), "fake png")

        described_class.new(project_root: project, destination: dest).copy

        expect(File.read(File.join(dest, "game", "scenes", "main.rb"))).to eq("class MainScene; end")
        expect(File.read(File.join(dest, "config.rb"))).to eq("GAME = Dama::Game.new {}")
        expect(File.read(File.join(dest, "assets", "sprite.png"))).to eq("fake png")
      end
    end

    it "skips missing directories and files without raising" do
      Dir.mktmpdir do |root|
        project = File.join(root, "project")
        dest = File.join(root, "release")
        FileUtils.mkdir_p([project, dest])

        described_class.new(project_root: project, destination: dest).copy

        expect(Dir.children(dest)).to be_empty
      end
    end

    it "copies only the directories that exist" do
      Dir.mktmpdir do |root|
        project = File.join(root, "project")
        dest = File.join(root, "release")
        FileUtils.mkdir_p([project, dest])

        File.write(File.join(project, "config.rb"), "config only")

        described_class.new(project_root: project, destination: dest).copy

        expect(File.exist?(File.join(dest, "config.rb"))).to be(true)
        expect(File.exist?(File.join(dest, "game"))).to be(false)
        expect(File.exist?(File.join(dest, "assets"))).to be(false)
      end
    end
  end
end
