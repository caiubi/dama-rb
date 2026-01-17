RSpec.describe Dama::Component::AttributeDefinition do
  describe "#initialize" do
    subject(:definition) { described_class.new(name: :x, default: 42) }

    it "stores the attribute name" do
      expect(definition.name).to eq(:x)
    end

    it "stores the default value" do
      expect(definition.default).to eq(42)
    end
  end
end
