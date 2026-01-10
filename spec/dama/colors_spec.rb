require "spec_helper"

RSpec.describe Dama::Colors do
  describe "Color" do
    subject(:color) { Dama::Colors::Color.new(r: 0.5, g: 0.6, b: 0.7, a: 0.8) }

    it "stores RGBA values" do
      expect(color.r).to eq(0.5)
      expect(color.g).to eq(0.6)
      expect(color.b).to eq(0.7)
      expect(color.a).to eq(0.8)
    end

    it "is frozen (immutable)" do
      expect(color).to be_frozen
    end

    describe "#to_h" do
      it "returns a hash suitable for double-splatting into draw calls" do
        expect(color.to_h).to eq(r: 0.5, g: 0.6, b: 0.7, a: 0.8)
      end
    end

    describe "#with_alpha" do
      it "returns a new Color with the specified alpha" do
        transparent = color.with_alpha(a: 0.3)

        expect(transparent.r).to eq(0.5)
        expect(transparent.g).to eq(0.6)
        expect(transparent.b).to eq(0.7)
        expect(transparent.a).to eq(0.3)
      end

      it "does not mutate the original" do
        color.with_alpha(a: 0.1)

        expect(color.a).to eq(0.8)
      end
    end
  end

  describe "named constants" do
    {
      RED: { r: 0.9, g: 0.2, b: 0.2, a: 1.0 },
      DARK_RED: { r: 0.6, g: 0.1, b: 0.1, a: 1.0 },
      WHITE: { r: 1.0, g: 1.0, b: 1.0, a: 1.0 },
      CREAM: { r: 0.96, g: 0.93, b: 0.87, a: 1.0 },
      BLACK: { r: 0.0, g: 0.0, b: 0.0, a: 1.0 },
      GRAY: { r: 0.5, g: 0.5, b: 0.5, a: 1.0 },
      DARK_BROWN: { r: 0.44, g: 0.26, b: 0.13, a: 1.0 },
      LIGHT_TAN: { r: 0.87, g: 0.72, b: 0.53, a: 1.0 },
      GREEN: { r: 0.2, g: 0.8, b: 0.3, a: 1.0 },
      GOLD: { r: 1.0, g: 0.84, b: 0.0, a: 1.0 },
      YELLOW: { r: 1.0, g: 1.0, b: 0.0, a: 1.0 },
      BLUE: { r: 0.2, g: 0.4, b: 0.9, a: 1.0 },
      LIGHT_GRAY: { r: 0.96, g: 0.96, b: 0.96, a: 1.0 },
      DARK_GRAY: { r: 0.07, g: 0.07, b: 0.07, a: 1.0 },
      CHARCOAL: { r: 0.32, g: 0.35, b: 0.38, a: 1.0 },
      SLATE: { r: 0.13, g: 0.15, b: 0.17, a: 1.0 },
    }.each do |name, expected_values|
      describe name.to_s do
        subject(:color) { described_class.const_get(name) }

        it "has the correct RGBA values" do
          expect(color.to_h).to eq(expected_values)
        end

        it "is frozen" do
          expect(color).to be_frozen
        end
      end
    end
  end
end
