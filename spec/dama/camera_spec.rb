require "spec_helper"

RSpec.describe Dama::Camera do
  subject(:camera) { described_class.new(viewport_width: 800.0, viewport_height: 600.0) }

  describe "#initialize" do
    it "defaults to origin with zoom 1.0" do
      expect(camera.x).to eq(0.0)
      expect(camera.y).to eq(0.0)
      expect(camera.zoom).to eq(1.0)
    end
  end

  describe "#move_to" do
    it "sets the camera position" do
      camera.move_to(x: 100.0, y: 200.0)

      expect(camera.x).to eq(100.0)
      expect(camera.y).to eq(200.0)
    end
  end

  describe "#move_by" do
    it "adjusts position by delta" do
      camera.move_to(x: 50.0, y: 50.0)
      camera.move_by(dx: 10.0, dy: -20.0)

      expect(camera.x).to eq(60.0)
      expect(camera.y).to eq(30.0)
    end
  end

  describe "#zoom_to" do
    it "sets the zoom level" do
      camera.zoom_to(level: 2.0)

      expect(camera.zoom).to eq(2.0)
    end

    it "clamps zoom to minimum 0.1" do
      camera.zoom_to(level: 0.01)

      expect(camera.zoom).to eq(0.1)
    end

    it "clamps zoom to maximum 10.0" do
      camera.zoom_to(level: 99.0)

      expect(camera.zoom).to eq(10.0)
    end
  end

  describe "#world_to_screen" do
    it "converts world coordinates to screen coordinates at default camera" do
      result = camera.world_to_screen(world_x: 100.0, world_y: 200.0)

      expect(result).to eq({ screen_x: 100.0, screen_y: 200.0 })
    end

    it "translates based on camera position" do
      camera.move_to(x: 50.0, y: 100.0)

      result = camera.world_to_screen(world_x: 150.0, world_y: 200.0)

      expect(result).to eq({ screen_x: 100.0, screen_y: 100.0 })
    end

    it "scales based on zoom" do
      camera.zoom_to(level: 2.0)

      result = camera.world_to_screen(world_x: 100.0, world_y: 50.0)

      expect(result).to eq({ screen_x: 200.0, screen_y: 100.0 })
    end

    it "applies both translation and zoom" do
      camera.move_to(x: 50.0, y: 50.0)
      camera.zoom_to(level: 2.0)

      result = camera.world_to_screen(world_x: 100.0, world_y: 100.0)

      expect(result).to eq({ screen_x: 100.0, screen_y: 100.0 })
    end
  end

  describe "#screen_to_world" do
    it "inverts world_to_screen at default camera" do
      result = camera.screen_to_world(screen_x: 100.0, screen_y: 200.0)

      expect(result).to eq({ world_x: 100.0, world_y: 200.0 })
    end

    it "inverts translation" do
      camera.move_to(x: 50.0, y: 100.0)

      result = camera.screen_to_world(screen_x: 100.0, screen_y: 100.0)

      expect(result).to eq({ world_x: 150.0, world_y: 200.0 })
    end

    it "inverts zoom" do
      camera.zoom_to(level: 2.0)

      result = camera.screen_to_world(screen_x: 200.0, screen_y: 100.0)

      expect(result).to eq({ world_x: 100.0, world_y: 50.0 })
    end
  end

  describe "#visible?" do
    it "returns true for objects inside the viewport" do
      expect(camera.visible?(x: 100.0, y: 100.0, width: 50.0, height: 50.0)).to be(true)
    end

    it "returns false for objects completely outside to the right" do
      expect(camera.visible?(x: 900.0, y: 100.0, width: 50.0, height: 50.0)).to be(false)
    end

    it "returns false for objects completely above" do
      expect(camera.visible?(x: 100.0, y: -100.0, width: 50.0, height: 50.0)).to be(false)
    end

    it "returns true for objects partially visible" do
      expect(camera.visible?(x: 780.0, y: 100.0, width: 50.0, height: 50.0)).to be(true)
    end

    it "accounts for camera position" do
      camera.move_to(x: 500.0, y: 500.0)

      expect(camera.visible?(x: 100.0, y: 100.0, width: 50.0, height: 50.0)).to be(false)
      expect(camera.visible?(x: 600.0, y: 600.0, width: 50.0, height: 50.0)).to be(true)
    end

    it "accounts for zoom" do
      camera.zoom_to(level: 0.5)
      # At zoom 0.5, viewport covers 1600x1200 in world space.
      expect(camera.visible?(x: 1500.0, y: 100.0, width: 50.0, height: 50.0)).to be(true)
    end
  end

  describe "#follow" do
    let(:target) { Struct.new(:x, :y).new(300.0, 400.0) }

    it "centers the camera on the target" do
      camera.follow(target:)

      expect(camera.x).to eq(300.0)
      expect(camera.y).to eq(400.0)
    end

    it "tracks moving targets on subsequent calls" do
      camera.follow(target:)
      target.x = 500.0
      target.y = 100.0
      camera.follow(target:)

      expect(camera.x).to eq(500.0)
      expect(camera.y).to eq(100.0)
    end

    it "applies smoothing when lerp factor is less than 1.0" do
      camera.move_to(x: 0.0, y: 0.0)
      camera.follow(target:, lerp: 0.5)

      expect(camera.x).to eq(150.0)
      expect(camera.y).to eq(200.0)
    end
  end
end
