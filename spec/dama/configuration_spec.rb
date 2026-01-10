RSpec.describe Dama::Configuration do
  describe "#initialize" do
    context "with default values" do
      subject(:config) { described_class.new }

      it "has default width of 800" do
        expect(config.width).to eq(800)
      end

      it "has default height of 600" do
        expect(config.height).to eq(600)
      end

      it "has default title" do
        expect(config.title).to eq("Dama Game")
      end

      it "is not headless by default" do
        expect(config.headless).to be(false)
      end

      it "returns resolution as [width, height]" do
        expect(config.resolution).to eq([800, 600])
      end
    end

    context "with custom values" do
      subject(:config) do
        described_class.new(width: 1280, height: 720, title: "My Game", headless: true)
      end

      it "stores custom width" do
        expect(config.width).to eq(1280)
      end

      it "stores custom height" do
        expect(config.height).to eq(720)
      end

      it "stores custom title" do
        expect(config.title).to eq("My Game")
      end

      it "stores headless flag" do
        expect(config.headless).to be(true)
      end

      it "returns custom resolution" do
        expect(config.resolution).to eq([1280, 720])
      end
    end
  end
end
