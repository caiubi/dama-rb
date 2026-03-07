require "spec_helper"
require "tmpdir"

RSpec.describe "Camera integration" do
  include_context "with headless backend"

  let(:node_class) do
    Class.new(Dama::Node) do
      attribute :px, default: 32.0
      attribute :py, default: 32.0

      draw do
        circle(px, py, 10.0, r: 1.0, g: 0.0, b: 0.0, a: 1.0)
      end
    end
  end

  it "renders at world position when no camera is set" do
    nc = node_class
    scene_class = Class.new(Dama::Scene) do
      compose { add nc, as: :dot, px: 32.0, py: 32.0 }
    end

    registry = Dama::Registry.new
    scene = scene_class.new(registry:)
    scene.perform_compose

    backend.begin_frame
    backend.clear(r: 0.0, g: 0.0, b: 0.0, a: 1.0)
    scene.perform_draw(backend:)
    backend.end_frame

    Dir.mktmpdir do |dir|
      path = File.join(dir, "no_camera.png")
      backend.screenshot(output_path: path)
      img = ChunkyPNG::Image.from_file(path)
      red = ChunkyPNG::Color.r(img[32, 32])
      expect(red).to be > 200
    end
  end

  it "translates draw coordinates when camera is offset" do
    nc = node_class
    scene_class = Class.new(Dama::Scene) do
      compose { add nc, as: :dot, px: 32.0, py: 32.0 }
      enter { enable_camera(viewport_width: 64, viewport_height: 64) }
    end

    registry = Dama::Registry.new
    scene = scene_class.new(registry:)
    scene.perform_compose
    scene.perform_enter

    # Move camera so the dot is off-screen to the left.
    scene.camera.move_to(x: 100.0, y: 0.0)

    backend.begin_frame
    backend.clear(r: 0.0, g: 0.0, b: 0.0, a: 1.0)
    scene.perform_draw(backend:)
    backend.end_frame

    Dir.mktmpdir do |dir|
      path = File.join(dir, "offset_camera.png")
      backend.screenshot(output_path: path)
      img = ChunkyPNG::Image.from_file(path)
      # The dot at world(32,32) with camera at (100,0) renders at screen(-68,32) — off-screen.
      # Center pixel should be black (background).
      red = ChunkyPNG::Color.r(img[32, 32])
      expect(red).to be < 30
    end
  end
end
