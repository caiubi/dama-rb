require "spec_helper"

RSpec.describe Dama::SpriteSheet do
  describe "#initialize" do
    it "calculates frame count from texture dimensions" do
      sheet = described_class.new(
        texture_width: 128, texture_height: 64,
        frame_width: 32, frame_height: 32
      )

      expect(sheet.frame_count).to eq(8)
      expect(sheet.columns).to eq(4)
      expect(sheet.rows).to eq(2)
    end

    it "handles a single-row sheet" do
      sheet = described_class.new(
        texture_width: 96, texture_height: 32,
        frame_width: 32, frame_height: 32
      )

      expect(sheet.frame_count).to eq(3)
      expect(sheet.columns).to eq(3)
      expect(sheet.rows).to eq(1)
    end
  end

  describe "#frame_uv" do
    it "returns UV coordinates for the first frame" do
      sheet = described_class.new(
        texture_width: 128, texture_height: 64,
        frame_width: 32, frame_height: 32
      )

      uv = sheet.frame_uv(frame: 0)
      expect(uv).to eq({ u: 0.0, v: 0.0, u2: 0.25, v2: 0.5 })
    end

    it "returns UV coordinates for the second frame" do
      sheet = described_class.new(
        texture_width: 128, texture_height: 64,
        frame_width: 32, frame_height: 32
      )

      uv = sheet.frame_uv(frame: 1)
      expect(uv).to eq({ u: 0.25, v: 0.0, u2: 0.5, v2: 0.5 })
    end

    it "wraps to next row" do
      sheet = described_class.new(
        texture_width: 128, texture_height: 64,
        frame_width: 32, frame_height: 32
      )

      # Frame 4 = row 1, col 0
      uv = sheet.frame_uv(frame: 4)
      expect(uv).to eq({ u: 0.0, v: 0.5, u2: 0.25, v2: 1.0 })
    end

    it "clamps frame index to valid range" do
      sheet = described_class.new(
        texture_width: 64, texture_height: 32,
        frame_width: 32, frame_height: 32
      )

      uv = sheet.frame_uv(frame: 99)
      # Clamped to last frame (1)
      expect(uv).to eq({ u: 0.5, v: 0.0, u2: 1.0, v2: 1.0 })
    end
  end
end
