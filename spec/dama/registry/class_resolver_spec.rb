RSpec.describe Dama::Registry::ClassResolver do
  subject(:resolver) { described_class.new }

  # Anonymous classes need names for derive_key, so we use stub classes.
  let(:player_class) do
    stub_const("Player", Class.new(Dama::Node))
  end

  let(:menu_scene_class) do
    stub_const("MenuScene", Class.new(Dama::Scene))
  end

  describe "#register and #resolve" do
    it "registers a node class and resolves it by snake_case symbol" do
      resolver.register(klass: player_class, category: :node)
      expect(resolver.resolve(name: :player, category: :node)).to eq(player_class)
    end

    it "registers a scene class and resolves it by snake_case symbol" do
      resolver.register(klass: menu_scene_class, category: :scene)
      expect(resolver.resolve(name: :menu_scene, category: :scene)).to eq(menu_scene_class)
    end

    it "resolves by string name (case-insensitive)" do
      resolver.register(klass: player_class, category: :node)
      expect(resolver.resolve(name: "player", category: :node)).to eq(player_class)
    end

    it "raises KeyError for unregistered names" do
      expect { resolver.resolve(name: :unknown, category: :node) }.to raise_error(KeyError)
    end
  end
end
