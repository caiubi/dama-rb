RSpec.describe Dama::Component do
  let(:transform_class) do
    Class.new(described_class) do
      attribute :x, default: 0
      attribute :y, default: 0
      attribute :vx, default: 0
      attribute :vy, default: 0
    end
  end

  let(:sprite_class) do
    Class.new(described_class) do
      attribute :ref, default: nil
    end
  end

  describe ".attribute" do
    it "defines reader and writer methods for each attribute" do
      component = transform_class.new
      expect(component).to respond_to(:x)
      expect(component).to respond_to(:x=)
      expect(component).to respond_to(:y)
      expect(component).to respond_to(:vy)
    end

    it "registers attributes in the attribute_set" do
      names = transform_class.attribute_set.map(&:name)
      expect(names).to eq(%i[x y vx vy])
    end
  end

  describe "#initialize" do
    it "uses default values when no arguments are provided" do
      component = transform_class.new
      expect(component.x).to eq(0)
      expect(component.y).to eq(0)
      expect(component.vx).to eq(0)
      expect(component.vy).to eq(0)
    end

    it "accepts keyword arguments to override defaults" do
      component = transform_class.new(x: 50, y: 100)
      expect(component.x).to eq(50)
      expect(component.y).to eq(100)
      expect(component.vx).to eq(0)
      expect(component.vy).to eq(0)
    end

    it "accepts nil as an explicit default" do
      component = sprite_class.new
      expect(component.ref).to be_nil
    end

    it "accepts a value for a nil-default attribute" do
      component = sprite_class.new(ref: :main)
      expect(component.ref).to eq(:main)
    end
  end

  describe "attribute mutation" do
    it "allows writing and reading back values" do
      component = transform_class.new(x: 10)
      component.x = 42
      expect(component.x).to eq(42)
    end
  end

  describe "subclass isolation" do
    it "does not share attribute definitions between subclasses" do
      expect(transform_class.attribute_set.map(&:name)).to eq(%i[x y vx vy])
      expect(sprite_class.attribute_set.map(&:name)).to eq([:ref])
    end
  end
end
