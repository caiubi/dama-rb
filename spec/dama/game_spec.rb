require "spec_helper"
require "tmpdir"

RSpec.describe Dama::Game do
  let(:scene_class) do
    stub_const("TestScene", Class.new(Dama::Scene) do
      compose {}
    end)
  end

  before { scene_class }

  describe "#run_frames" do
    it "runs the game loop for exactly N frames in headless mode" do
      game = described_class.new do
        settings resolution: [64, 64], headless: true
        start_scene TestScene
      end

      expect { game.run_frames(3) }.not_to raise_error
    end

    it "loads the start scene and makes it current" do
      game = described_class.new do
        settings resolution: [64, 64], headless: true
        start_scene TestScene
      end

      game.run_frames(1)

      current = game.send(:current_scene)
      expect(current).to be_a(scene_class)
    end
  end

  describe "#start" do
    it "initializes the engine and runs the game loop" do
      game = described_class.new do
        settings resolution: [64, 64], headless: true
        start_scene TestScene
      end

      # Make poll_events return quit after 2 frames so start terminates.
      call_count = 0
      allow(game.backend).to receive(:poll_events) do
        call_count += 1
        call_count > 2
      end

      game.start

      current = game.send(:current_scene)
      expect(current).to be_a(scene_class)
      expect(call_count).to be > 2
    end
  end

  describe "#screenshot" do
    it "captures a screenshot to a file" do
      game = described_class.new do
        settings resolution: [64, 64], headless: true
        start_scene TestScene
      end

      # The engine must be initialized for screenshot to work.
      game.backend.initialize_engine(configuration: game.configuration)

      Dir.mktmpdir do |dir|
        path = File.join(dir, "test.png")
        game.screenshot(path)
        expect(File.exist?(path)).to be(true)
      end
    ensure
      game.backend.shutdown
    end
  end
end
