require "spec_helper"

RSpec.describe Dama::Input::MouseState do
  subject(:mouse) { described_class.new(backend:) }

  include_context "with headless backend"

  describe "#x" do
    it "returns the mouse x position from the backend" do
      expect(mouse.x).to eq(0.0)
    end
  end

  describe "#y" do
    it "returns the mouse y position from the backend" do
      expect(mouse.y).to eq(0.0)
    end
  end

  describe "#pressed?" do
    it "returns false for left button in headless mode" do
      expect(mouse.pressed?(button: :left)).to be(false)
    end

    it "returns false for right button in headless mode" do
      expect(mouse.pressed?(button: :right)).to be(false)
    end

    it "returns false for middle button in headless mode" do
      expect(mouse.pressed?(button: :middle)).to be(false)
    end

    it "raises KeyError for unknown button name" do
      expect { mouse.pressed?(button: :nonexistent) }.to raise_error(KeyError)
    end
  end

  describe "#just_pressed?" do
    it "returns false when no buttons are pressed" do
      mouse.update
      expect(mouse.just_pressed?(button: :left)).to be(false)
    end

    it "tracks state transitions across frames" do
      # In headless mode, mouse buttons are always released.
      # The edge detection logic still runs correctly.
      mouse.update
      mouse.update

      expect(mouse.just_pressed?(button: :left)).to be(false)
      expect(mouse.just_pressed?(button: :right)).to be(false)
      expect(mouse.just_pressed?(button: :middle)).to be(false)
    end
  end

  describe "#update" do
    it "can be called without error" do
      expect { mouse.update }.not_to raise_error
    end

    it "captures current state for edge detection" do
      mouse.update
      # After update, just_pressed? should be deterministic.
      expect(mouse.just_pressed?(button: :left)).to be(false)
    end
  end
end
