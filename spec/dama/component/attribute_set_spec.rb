RSpec.describe Dama::Component::AttributeSet do
  subject(:set) { described_class.new(owner: owner_class) }

  let(:owner_class) { Class.new(Dama::Component) }

  describe "#add" do
    it "stores an attribute definition" do
      set.add(name: :x, default: 0)
      expect(set.fetch(:x).name).to eq(:x)
      expect(set.fetch(:x).default).to eq(0)
    end

    it "defines accessor methods on the owner class" do
      set.add(name: :speed, default: 10)
      instance = owner_class.new
      expect(instance).to respond_to(:speed)
      expect(instance).to respond_to(:speed=)
    end
  end

  describe "#each" do
    it "iterates over all definitions in insertion order" do
      set.add(name: :x, default: 0)
      set.add(name: :y, default: 0)
      set.add(name: :z, default: 0)

      names = set.map(&:name)
      expect(names).to eq(%i[x y z])
    end
  end

  describe "#fetch" do
    it "raises KeyError for unknown attributes" do
      expect { set.fetch(:unknown) }.to raise_error(KeyError)
    end
  end
end
