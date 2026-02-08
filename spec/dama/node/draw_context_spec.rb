RSpec.describe Dama::Node::DrawContext do
  subject(:context) { described_class.new(node:, backend:) }

  include_context "with headless backend"

  let(:transform_class) do
    Class.new(Dama::Component) do
      attribute :x, default: 10.0
      attribute :y, default: 20.0
    end
  end

  let(:node_class) do
    tc = transform_class
    Class.new(Dama::Node) do
      component tc, as: :transform, x: 10.0, y: 20.0
      attribute :label, default: "test"
    end
  end

  let(:node) { node_class.new }

  describe "#rect" do
    it "renders a red rectangle that appears in the screenshot" do
      backend.begin_frame
      backend.clear(r: 0.0, g: 0.0, b: 0.0, a: 1.0)
      context.rect(0, 0, 64, 64, r: 1.0, g: 0.0, b: 0.0, a: 1.0)
      backend.end_frame

      Dir.mktmpdir do |dir|
        path = File.join(dir, "rect.png")
        backend.screenshot(output_path: path)
        img = ChunkyPNG::Image.from_file(path)
        red = ChunkyPNG::Color.r(img[32, 32])
        expect(red).to be > 200
      end
    end
  end

  describe "#triangle" do
    it "renders a green triangle that appears in the screenshot" do
      backend.begin_frame
      backend.clear(r: 0.0, g: 0.0, b: 0.0, a: 1.0)
      context.triangle(32, 0, 0, 63, 63, 63, r: 0.0, g: 1.0, b: 0.0, a: 1.0)
      backend.end_frame

      Dir.mktmpdir do |dir|
        path = File.join(dir, "tri.png")
        backend.screenshot(output_path: path)
        img = ChunkyPNG::Image.from_file(path)
        green = ChunkyPNG::Color.g(img[32, 40])
        expect(green).to be > 200
      end
    end
  end

  describe "#text" do
    it "renders text that produces non-black pixels" do
      backend.begin_frame
      backend.clear(r: 0.0, g: 0.0, b: 0.0, a: 1.0)
      context.text("X", 10, 10, size: 40.0, r: 1.0, g: 1.0, b: 1.0, a: 1.0)
      backend.end_frame

      Dir.mktmpdir do |dir|
        path = File.join(dir, "text.png")
        backend.screenshot(output_path: path)
        img = ChunkyPNG::Image.from_file(path)
        has_bright_pixel = img.pixels.any? { |p| ChunkyPNG::Color.r(p) > 30 }
        expect(has_bright_pixel).to be(true)
      end
    end
  end

  describe "#circle" do
    it "renders a blue circle that appears in the screenshot" do
      backend.begin_frame
      backend.clear(r: 0.0, g: 0.0, b: 0.0, a: 1.0)
      context.circle(32, 32, 20, r: 0.0, g: 0.0, b: 1.0, a: 1.0)
      backend.end_frame

      Dir.mktmpdir do |dir|
        path = File.join(dir, "circle.png")
        backend.screenshot(output_path: path)
        img = ChunkyPNG::Image.from_file(path)
        blue = ChunkyPNG::Color.b(img[32, 32])
        expect(blue).to be > 200
      end
    end
  end

  describe "direct access to node attributes and components" do
    it "exposes component accessors (e.g. transform)" do
      expect(context.transform.x).to eq(10.0)
      expect(context.transform.y).to eq(20.0)
    end

    it "exposes node attributes (e.g. label)" do
      expect(context.label).to eq("test")
    end

    it "raises NoMethodError for methods the node doesn't have" do
      expect { context.nonexistent_method }.to raise_error(NoMethodError)
    end
  end

  describe "#respond_to_missing?" do
    it "returns true for node methods" do
      expect(context.respond_to?(:transform)).to be(true)
      expect(context.respond_to?(:label)).to be(true)
    end

    it "returns false for unknown methods" do
      expect(context.respond_to?(:nonexistent)).to be(false)
    end
  end
end
