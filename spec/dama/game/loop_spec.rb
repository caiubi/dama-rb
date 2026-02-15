require "spec_helper"

RSpec.describe Dama::Game::Loop do
  include_context "with headless backend"

  let(:scene_class) do
    Class.new(Dama::Scene) { compose {} }
  end

  let(:scene) do
    s = scene_class.new(registry: Dama::Registry.new)
    s.perform_compose
    s
  end

  let(:input) { Dama::Input.new(backend:) }

  describe "#run" do
    it "breaks when poll_events signals quit" do
      call_count = 0
      allow(backend).to receive(:poll_events) do
        call_count += 1
        call_count >= 3
      end

      loop_instance = described_class.new(
        backend:,
        scene_provider: -> { scene },
        frame_controller: Dama::Debug::FrameController.new,
        input:,
        scene_transition: -> {},
      )

      loop_instance.run

      expect(call_count).to eq(3)
    end

    it "runs without a scene_transition callback" do
      loop_instance = described_class.new(
        backend:,
        scene_provider: -> { scene },
        frame_controller: Dama::Debug::FrameController.new(frame_limit: 2),
        input:,
      )

      expect { loop_instance.run }.not_to raise_error
    end
  end
end
