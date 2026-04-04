require "spec_helper"
require "tmpdir"

RSpec.describe "Dama.boot" do
  it "auto-loads game files, requires config, and starts the game" do
    Dir.mktmpdir do |root|
      game_dir = File.join(root, "game")
      FileUtils.mkdir_p(game_dir)

      # Minimal scene class.
      File.write(File.join(game_dir, "boot_test_scene.rb"), <<~RUBY)
        class BootTestScene < Dama::Scene
          compose {}
        end
      RUBY

      # Config that creates the game.
      File.write(File.join(root, "config.rb"), <<~RUBY)
        GAME = Dama::Game.new do
          settings resolution: [64, 64], headless: true
          start_scene BootTestScene
        end
      RUBY

      stub_const("ARGV", [])

      # GAME.start would block, so stub it.
      game_double = instance_double(Dama::Game, start: nil)
      allow(Dama::Game).to receive(:new).and_return(game_double)

      Dama.boot(root:)

      expect(defined?(BootTestScene)).to eq("constant")
      expect(game_double).to have_received(:start)
    end
  end

  it "launches web mode when ARGV[0] is 'web'" do
    Dir.mktmpdir do |root|
      game_dir = File.join(root, "game")
      FileUtils.mkdir_p(game_dir)

      File.write(File.join(game_dir, "web_test_scene.rb"), <<~RUBY)
        class WebTestScene < Dama::Scene
          compose {}
        end
      RUBY

      File.write(File.join(root, "config.rb"), <<~RUBY)
        GAME = Dama::Game.new do
          settings resolution: [64, 64], headless: true
          start_scene WebTestScene
        end
      RUBY

      stub_const("ARGV", ["web"])
      allow(Dama::WebBuilder).to receive(:build_and_serve)

      Dama.boot(root:)

      expect(Dama::WebBuilder).to have_received(:build_and_serve).with(project_root: root, port: 8080)
    end
  end
end
