require "spec_helper"

RSpec.describe Dama::Physics::Collider do
  describe ".rect" do
    it "creates a rect collider with width and height" do
      collider = described_class.rect(width: 32.0, height: 16.0)
      expect(collider.shape).to eq(:rect)
      expect(collider.width).to eq(32.0)
      expect(collider.height).to eq(16.0)
    end
  end

  describe ".circle" do
    it "creates a circle collider with radius" do
      collider = described_class.circle(radius: 20.0)
      expect(collider.shape).to eq(:circle)
      expect(collider.radius).to eq(20.0)
    end
  end

  describe "#overlap?" do
    context "with rect vs rect" do
      it "returns true when rects overlap" do
        a = described_class.rect(width: 40.0, height: 40.0)
        b = described_class.rect(width: 40.0, height: 40.0)

        result = a.overlap?(other: b, ax: 0.0, ay: 0.0, bx: 20.0, by: 20.0)
        expect(result).to be(true)
      end

      it "returns false when rects do not overlap" do
        a = described_class.rect(width: 40.0, height: 40.0)
        b = described_class.rect(width: 40.0, height: 40.0)

        result = a.overlap?(other: b, ax: 0.0, ay: 0.0, bx: 100.0, by: 100.0)
        expect(result).to be(false)
      end

      it "returns false when rects touch exactly at edges" do
        a = described_class.rect(width: 40.0, height: 40.0)
        b = described_class.rect(width: 40.0, height: 40.0)

        result = a.overlap?(other: b, ax: 0.0, ay: 0.0, bx: 40.0, by: 0.0)
        expect(result).to be(false)
      end
    end

    context "with circle vs circle" do
      it "returns true when circles overlap" do
        a = described_class.circle(radius: 20.0)
        b = described_class.circle(radius: 20.0)

        result = a.overlap?(other: b, ax: 0.0, ay: 0.0, bx: 30.0, by: 0.0)
        expect(result).to be(true)
      end

      it "returns false when circles do not overlap" do
        a = described_class.circle(radius: 20.0)
        b = described_class.circle(radius: 20.0)

        result = a.overlap?(other: b, ax: 0.0, ay: 0.0, bx: 50.0, by: 0.0)
        expect(result).to be(false)
      end
    end

    context "with circle vs rect" do
      it "returns true when circle overlaps rect (circle first)" do
        a = described_class.circle(radius: 15.0)
        b = described_class.rect(width: 40.0, height: 40.0)

        result = a.overlap?(other: b, ax: 50.0, ay: 20.0, bx: 0.0, by: 0.0)
        expect(result).to be(true)
      end
    end

    context "with rect vs circle" do
      it "returns true when circle overlaps rect" do
        a = described_class.rect(width: 40.0, height: 40.0)
        b = described_class.circle(radius: 15.0)

        result = a.overlap?(other: b, ax: 0.0, ay: 0.0, bx: 50.0, by: 20.0)
        expect(result).to be(true)
      end

      it "returns false when circle is far from rect" do
        a = described_class.rect(width: 40.0, height: 40.0)
        b = described_class.circle(radius: 10.0)

        result = a.overlap?(other: b, ax: 0.0, ay: 0.0, bx: 100.0, by: 100.0)
        expect(result).to be(false)
      end
    end
  end

  describe "#separation" do
    it "returns the minimum translation vector to separate two overlapping rects" do
      a = described_class.rect(width: 40.0, height: 40.0)
      b = described_class.rect(width: 40.0, height: 40.0)

      sep = a.separation(other: b, ax: 0.0, ay: 0.0, bx: 30.0, by: 0.0)
      # Overlap is 10 on x-axis. Separation pushes b right by 10.
      expect(sep[:dx]).to eq(10.0)
      expect(sep[:dy]).to eq(0.0)
    end

    it "separates along the axis of least penetration" do
      a = described_class.rect(width: 40.0, height: 40.0)
      b = described_class.rect(width: 40.0, height: 40.0)

      sep = a.separation(other: b, ax: 0.0, ay: 0.0, bx: 35.0, by: 10.0)
      # x overlap: 5, y overlap: 30. Separates on x (least penetration).
      expect(sep[:dx]).to eq(5.0)
      expect(sep[:dy]).to eq(0.0)
    end

    it "separates two overlapping circles" do
      a = described_class.circle(radius: 20.0)
      b = described_class.circle(radius: 20.0)

      sep = a.separation(other: b, ax: 0.0, ay: 0.0, bx: 30.0, by: 0.0)
      expect(sep).not_to be_nil
      expect(sep[:dx]).to be > 0.0 # push b to the right
    end

    it "separates coincident circles along arbitrary axis" do
      a = described_class.circle(radius: 10.0)
      b = described_class.circle(radius: 10.0)

      sep = a.separation(other: b, ax: 5.0, ay: 5.0, bx: 5.0, by: 5.0)
      expect(sep).not_to be_nil
      expect(sep[:dx]).to eq(20.0)
    end

    it "separates rect vs circle" do
      a = described_class.rect(width: 40.0, height: 40.0)
      b = described_class.circle(radius: 15.0)

      sep = a.separation(other: b, ax: 0.0, ay: 0.0, bx: 50.0, by: 20.0)
      expect(sep).not_to be_nil
      expect(sep[:dx]).to be > 0.0
    end

    it "returns nil for non-overlapping rect vs circle" do
      a = described_class.rect(width: 40.0, height: 40.0)
      b = described_class.circle(radius: 5.0)

      sep = a.separation(other: b, ax: 0.0, ay: 0.0, bx: 100.0, by: 100.0)
      expect(sep).to be_nil
    end

    it "separates circle vs rect" do
      a = described_class.circle(radius: 15.0)
      b = described_class.rect(width: 40.0, height: 40.0)

      sep = a.separation(other: b, ax: 50.0, ay: 20.0, bx: 0.0, by: 0.0)
      expect(sep).not_to be_nil
    end

    it "returns nil for non-overlapping circle vs rect" do
      a = described_class.circle(radius: 5.0)
      b = described_class.rect(width: 40.0, height: 40.0)

      sep = a.separation(other: b, ax: 100.0, ay: 100.0, bx: 0.0, by: 0.0)
      expect(sep).to be_nil
    end

    it "separates when b is to the left of a" do
      a = described_class.rect(width: 40.0, height: 40.0)
      b = described_class.rect(width: 40.0, height: 40.0)

      sep = a.separation(other: b, ax: 30.0, ay: 0.0, bx: 0.0, by: 0.0)
      expect(sep[:dx]).to be < 0.0 # push b to the left
    end

    it "separates when b is above a" do
      a = described_class.rect(width: 40.0, height: 40.0)
      b = described_class.rect(width: 40.0, height: 40.0)

      sep = a.separation(other: b, ax: 0.0, ay: 30.0, bx: 0.0, by: 0.0)
      expect(sep[:dy]).to be < 0.0
    end

    it "handles b extending beyond a on both axes" do
      # b.right > a.right AND b.bottom > a.bottom
      a = described_class.rect(width: 20.0, height: 20.0)
      b = described_class.rect(width: 40.0, height: 40.0)

      sep = a.separation(other: b, ax: 10.0, ay: 10.0, bx: 5.0, by: 5.0)
      expect(sep).not_to be_nil
    end

    it "returns nil for non-overlapping circles" do
      a = described_class.circle(radius: 10.0)
      b = described_class.circle(radius: 10.0)

      sep = a.separation(other: b, ax: 0.0, ay: 0.0, bx: 100.0, by: 0.0)
      expect(sep).to be_nil
    end

    it "returns nil for unknown shape combination separation" do
      a = described_class.new(shape: :polygon, width: 0, height: 0, radius: 0)
      b = described_class.rect(width: 10, height: 10)

      expect(a.separation(other: b, ax: 0, ay: 0, bx: 0, by: 0)).to be_nil
    end

    it "separates coincident rect-circle with fallback" do
      a = described_class.rect(width: 40.0, height: 40.0)
      b = described_class.circle(radius: 10.0)

      sep = a.separation(other: b, ax: 0.0, ay: 0.0, bx: 20.0, by: 20.0)
      expect(sep).not_to be_nil
    end

    it "separates along y-axis when y penetration is less than x" do
      a = described_class.rect(width: 40.0, height: 40.0)
      b = described_class.rect(width: 40.0, height: 40.0)

      # b is mostly below a: x overlap = 30, y overlap = 5 → separate on y
      sep = a.separation(other: b, ax: 0.0, ay: 0.0, bx: 10.0, by: 35.0)
      expect(sep[:dx]).to eq(0.0)
      expect(sep[:dy]).to be > 0.0
    end

    it "returns nil when shapes do not overlap" do
      a = described_class.rect(width: 40.0, height: 40.0)
      b = described_class.rect(width: 40.0, height: 40.0)

      sep = a.separation(other: b, ax: 0.0, ay: 0.0, bx: 100.0, by: 100.0)
      expect(sep).to be_nil
    end
  end
end
