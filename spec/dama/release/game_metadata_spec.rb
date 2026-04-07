require "spec_helper"
require "tmpdir"

RSpec.describe Dama::Release::GameMetadata do
  describe "#title" do
    it "extracts the title from config.rb" do
      Dir.mktmpdir do |dir|
        File.write(File.join(dir, "config.rb"), <<~RUBY)
          GAME = Dama::Game.new do
            settings resolution: [800, 600], title: "My Awesome Game"
            start_scene MainScene
          end
        RUBY

        metadata = described_class.new(project_root: dir)

        expect(metadata.title).to eq("My Awesome Game")
      end
    end

    it "extracts the title when settings span multiple lines" do
      Dir.mktmpdir do |dir|
        File.write(File.join(dir, "config.rb"), <<~RUBY)
          GAME = Dama::Game.new do
            settings(
              resolution: [1024, 768],
              title: "Checkers Deluxe"
            )
            start_scene MainScene
          end
        RUBY

        metadata = described_class.new(project_root: dir)

        expect(metadata.title).to eq("Checkers Deluxe")
      end
    end

    it "falls back to directory name when config.rb has no title" do
      Dir.mktmpdir("my-game-project") do |dir|
        File.write(File.join(dir, "config.rb"), <<~RUBY)
          GAME = Dama::Game.new do
            start_scene MainScene
          end
        RUBY

        metadata = described_class.new(project_root: dir)

        expect(metadata.title).to eq(File.basename(dir))
      end
    end

    it "falls back to directory name when config.rb does not exist" do
      Dir.mktmpdir("fallback-game") do |dir|
        metadata = described_class.new(project_root: dir)

        expect(metadata.title).to eq(File.basename(dir))
      end
    end
  end

  describe "#release_name" do
    it "strips filesystem-unsafe characters from the title" do
      Dir.mktmpdir do |dir|
        File.write(File.join(dir, "config.rb"), <<~RUBY)
          GAME = Dama::Game.new do
            settings resolution: [800, 600], title: "<>:Demo"
            start_scene MainScene
          end
        RUBY

        metadata = described_class.new(project_root: dir)

        expect(metadata.release_name).to eq("Demo")
      end
    end

    it "collapses consecutive unsafe characters into a single space" do
      Dir.mktmpdir do |dir|
        File.write(File.join(dir, "config.rb"), <<~RUBY)
          GAME = Dama::Game.new do
            settings resolution: [800, 600], title: "Game::V2"
            start_scene MainScene
          end
        RUBY

        metadata = described_class.new(project_root: dir)

        expect(metadata.release_name).to eq("Game V2")
      end
    end

    it "returns an unchanged title when no unsafe characters are present" do
      Dir.mktmpdir do |dir|
        File.write(File.join(dir, "config.rb"), <<~RUBY)
          GAME = Dama::Game.new do
            settings resolution: [800, 600], title: "My Awesome Game"
            start_scene MainScene
          end
        RUBY

        metadata = described_class.new(project_root: dir)

        expect(metadata.release_name).to eq("My Awesome Game")
      end
    end
  end

  describe "#resolution" do
    it "extracts the resolution from config.rb" do
      Dir.mktmpdir do |dir|
        File.write(File.join(dir, "config.rb"), <<~RUBY)
          GAME = Dama::Game.new do
            settings resolution: [1024, 768], title: "My Game"
            start_scene MainScene
          end
        RUBY

        metadata = described_class.new(project_root: dir)

        expect(metadata.resolution).to eq([1024, 768])
      end
    end

    it "returns default resolution when config.rb has no resolution" do
      Dir.mktmpdir do |dir|
        File.write(File.join(dir, "config.rb"), <<~RUBY)
          GAME = Dama::Game.new do
            start_scene MainScene
          end
        RUBY

        metadata = described_class.new(project_root: dir)

        expect(metadata.resolution).to eq([800, 600])
      end
    end

    it "returns default resolution when config.rb does not exist" do
      Dir.mktmpdir do |dir|
        metadata = described_class.new(project_root: dir)

        expect(metadata.resolution).to eq([800, 600])
      end
    end
  end
end
