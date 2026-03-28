require "spec_helper"

RSpec.describe Dama::CommandBuffer do
  subject(:buffer) { described_class.new }

  describe "#empty?" do
    it "is true when no commands have been pushed" do
      expect(buffer).to be_empty
    end

    it "is false after pushing a command" do
      buffer.push_rect(x: 0, y: 0, w: 10, h: 10, r: 1.0, g: 0.0, b: 0.0, a: 1.0)
      expect(buffer).not_to be_empty
    end
  end

  describe "#float_count" do
    it "returns 0 when empty" do
      expect(buffer.float_count).to eq(0)
    end
  end

  describe "#push_circle" do
    it "appends 9 floats: [tag=0, cx, cy, radius, r, g, b, a, segments]" do
      buffer.push_circle(cx: 50.0, cy: 50.0, radius: 20.0, r: 1.0, g: 0.0, b: 0.0, a: 1.0, segments: 32)

      expect(buffer.float_count).to eq(9)
      expect(buffer.to_a).to eq([0.0, 50.0, 50.0, 20.0, 1.0, 0.0, 0.0, 1.0, 32.0])
    end
  end

  describe "#push_rect" do
    it "appends 9 floats: [tag=1, x, y, w, h, r, g, b, a]" do
      buffer.push_rect(x: 10.0, y: 20.0, w: 100.0, h: 50.0, r: 0.0, g: 1.0, b: 0.0, a: 1.0)

      expect(buffer.float_count).to eq(9)
      expect(buffer.to_a).to eq([1.0, 10.0, 20.0, 100.0, 50.0, 0.0, 1.0, 0.0, 1.0])
    end
  end

  describe "#push_triangle" do
    it "appends 11 floats: [tag=2, x1, y1, x2, y2, x3, y3, r, g, b, a]" do
      buffer.push_triangle(x1: 0.0, y1: 0.0, x2: 50.0, y2: 0.0, x3: 25.0, y3: 50.0,
                           r: 0.0, g: 0.0, b: 1.0, a: 1.0)

      expect(buffer.float_count).to eq(11)
      expect(buffer.to_a).to eq([2.0, 0.0, 0.0, 50.0, 0.0, 25.0, 50.0, 0.0, 0.0, 1.0, 1.0])
    end
  end

  describe "#push_sprite" do
    it "appends 14 floats: [tag=3, handle, x, y, w, h, r, g, b, a, u0, v0, u1, v1]" do
      buffer.push_sprite(texture_handle: 42, x: 10.0, y: 20.0, w: 64.0, h: 64.0,
                         r: 1.0, g: 1.0, b: 1.0, a: 1.0,
                         u_min: 0.0, v_min: 0.0, u_max: 1.0, v_max: 1.0)

      expect(buffer.float_count).to eq(14)
      expect(buffer.to_a).to eq([3.0, 42.0, 10.0, 20.0, 64.0, 64.0, 1.0, 1.0, 1.0, 1.0, 0.0, 0.0, 1.0, 1.0])
    end
  end

  describe "multiple commands" do
    it "accumulates floats from sequential pushes" do
      buffer.push_rect(x: 0, y: 0, w: 10, h: 10, r: 1.0, g: 0.0, b: 0.0, a: 1.0)
      buffer.push_circle(cx: 50, cy: 50, radius: 10, r: 0.0, g: 1.0, b: 0.0, a: 1.0, segments: 8)

      expect(buffer.float_count).to eq(18) # 9 + 9
    end
  end

  describe "#clear" do
    it "empties the buffer" do
      buffer.push_rect(x: 0, y: 0, w: 10, h: 10, r: 1.0, g: 0.0, b: 0.0, a: 1.0)
      buffer.clear

      expect(buffer).to be_empty
      expect(buffer.float_count).to eq(0)
    end
  end
end
