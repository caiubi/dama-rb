require "spec_helper"

RSpec.describe "Scene switching" do
  include_context "with headless backend"

  let(:scene_a_class) do
    stub_const("SceneA", Class.new(Dama::Scene) do
      compose {}

      enter do
        @entered = true
      end

      update do |_dt, _input|
        switch_to(SceneB)
      end

      def entered? = !!@entered
    end)
  end

  let(:scene_b_class) do
    stub_const("SceneB", Class.new(Dama::Scene) do
      compose {}

      enter do
        @entered = true
      end

      def entered? = !!@entered
    end)
  end

  it "switches scenes between frames" do
    scene_a_class
    scene_b_class

    game = Dama::Game.new do
      settings resolution: [64, 64], headless: true
      start_scene SceneA
    end

    game.run_frames(3)

    current = game.send(:current_scene)
    expect(current).to be_a(scene_b_class)
    expect(current.entered?).to be(true)
  end
end
