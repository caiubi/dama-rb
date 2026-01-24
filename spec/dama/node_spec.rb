RSpec.describe Dama::Node do
  let(:transform_class) do
    Class.new(Dama::Component) do
      attribute :x, default: 0
      attribute :y, default: 0
    end
  end

  let(:player_class) do
    tc = transform_class
    Class.new(described_class) do
      component tc, as: :transform, x: 50, y: 50
      attribute :name, default: "Player"
    end
  end

  describe ".component" do
    it "registers a component slot keyed by the `as:` name" do
      expect(player_class.component_slots).to have_key(:transform)
    end

    it "stores default values for the component" do
      slot = player_class.component_slots.fetch(:transform)
      expect(slot.defaults).to eq(x: 50, y: 50)
    end

    it "defines a reader method named by `as:`" do
      node = player_class.new
      expect(node.transform).to be_a(transform_class)
      expect(node.transform.x).to eq(50)
    end
  end

  describe ".attribute" do
    it "defines reader and writer for the attribute" do
      node = player_class.new
      expect(node).to respond_to(:name)
      expect(node).to respond_to(:name=)
    end
  end

  describe "#initialize" do
    it "instantiates components with their defaults" do
      node = player_class.new
      expect(node.transform.x).to eq(50)
      expect(node.transform.y).to eq(50)
    end

    it "initializes attributes with their defaults" do
      node = player_class.new
      expect(node.name).to eq("Player")
    end

    it "accepts attribute overrides" do
      node = player_class.new(name: "Hero")
      expect(node.name).to eq("Hero")
    end
  end
end
