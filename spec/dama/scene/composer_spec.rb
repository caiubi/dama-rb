RSpec.describe Dama::Scene::Composer do
  subject(:composer) { described_class.new(scene_graph:, registry:, scene:) }

  let(:transform_class) do
    Class.new(Dama::Component) do
      attribute :x, default: 0
      attribute :y, default: 0
    end
  end

  let(:player_class) do
    tc = transform_class
    stub_const("Player", Class.new(Dama::Node) do
      component tc, as: :transform, x: 50, y: 50
      attribute :name, default: "Hero"
    end)
  end

  let(:slime_class) do
    stub_const("Slime", Class.new(Dama::Node) do
      attribute :name, default: "Slime"
    end)
  end

  let(:registry) { Dama::Registry.new }
  let(:scene_graph) { Dama::SceneGraph::Tree.new }
  let(:scene) { Dama::Scene.new(registry:) }

  before do
    registry.register(klass: player_class, category: :node)
    registry.register(klass: slime_class, category: :node)
  end

  describe "#add" do
    context "with a class argument" do
      it "creates and adds a node instance" do
        composer.add(player_class, as: :hero)
        expect(scene_graph.query.by_id(id: :hero).node).to be_a(player_class)
      end
    end

    context "with a symbol argument" do
      it "resolves the class from the registry" do
        composer.add(:slime, as: :s1)
        expect(scene_graph.query.by_id(id: :s1).node).to be_a(slime_class)
      end
    end

    context "with a string argument" do
      it "resolves the class from the registry" do
        composer.add("slime", as: :s2)
        expect(scene_graph.query.by_id(id: :s2).node).to be_a(slime_class)
      end
    end

    context "with an instance argument" do
      it "uses the instance directly" do
        instance = slime_class.new(name: "Boss")
        composer.add(instance, as: :boss)
        result = scene_graph.query.by_id(id: :boss)
        expect(result.node).to equal(instance)
        expect(result.node.name).to eq("Boss")
      end
    end

    it "registers a named accessor on the scene" do
      composer.add(player_class, as: :hero)
      expect(scene.hero.node).to be_a(player_class)
    end
  end

  describe "#group" do
    it "creates a named group and adds nodes to it" do
      composer.group(:ui) do
        add(:player, as: :hud)
      end

      expect(scene_graph.query.by_id(id: :hud)).not_to be_nil
    end

    it "allows path-based lookup of grouped nodes" do
      composer.group(:ui) do
        add(:player, as: :hud)
      end

      expect(scene_graph.query.by_path(path: "ui/hud")).not_to be_nil
    end
  end
end
