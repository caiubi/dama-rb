RSpec.describe Dama::SceneGraph::Tree do
  subject(:tree) { described_class.new }

  let(:node_class) { Class.new(Dama::Node) }
  let(:node_a) { Dama::SceneGraph::InstanceNode.new(id: :a, node: node_class.new, tags: [:enemy]) }
  let(:node_b) { Dama::SceneGraph::InstanceNode.new(id: :b, node: node_class.new, tags: %i[enemy boss]) }
  let(:node_c) { Dama::SceneGraph::InstanceNode.new(id: :c, node: node_class.new, tags: []) }

  describe "#add" do
    it "adds a node to the root" do
      tree.add(instance_node: node_a)
      expect(tree.query.by_id(id: :a)).to eq(node_a)
    end

    it "adds a node to a named group" do
      tree.add_group(name: :ui)
      tree.add(instance_node: node_c, parent_group: :ui)
      expect(tree.query.by_id(id: :c)).to eq(node_c)
    end
  end

  describe "#remove" do
    it "removes a node by id" do
      tree.add(instance_node: node_a)
      tree.remove(id: :a)
      expect { tree.query.by_id(id: :a) }.to raise_error(KeyError)
    end

    it "removes node from tag index" do
      tree.add(instance_node: node_a)
      tree.remove(id: :a)
      expect(tree.query.by_tag(tag: :enemy)).to eq([])
    end
  end

  describe "#each_node" do
    it "traverses all nodes including those in groups" do
      tree.add(instance_node: node_a)
      tree.add_group(name: :ui)
      tree.add(instance_node: node_c, parent_group: :ui)

      visited = []
      tree.each_node { |n| visited << n.id }
      expect(visited).to contain_exactly(:a, :c)
    end
  end

  describe "#traverse" do
    it "delegates to each_node for polymorphic tree walking" do
      tree.add(instance_node: node_a)
      tree.add(instance_node: node_b)

      visited = []
      tree.traverse { |n| visited << n.id }
      expect(visited).to contain_exactly(:a, :b)
    end
  end

  describe "#query" do
    before do
      tree.add(instance_node: node_a)
      tree.add(instance_node: node_b)
    end

    it "finds by id" do
      expect(tree.query.by_id(id: :a)).to eq(node_a)
    end

    it "finds by class" do
      expect(tree.query.by_class(klass: node_class)).to contain_exactly(node_a, node_b)
    end

    it "finds by tag" do
      expect(tree.query.by_tag(tag: :enemy)).to contain_exactly(node_a, node_b)
      expect(tree.query.by_tag(tag: :boss)).to contain_exactly(node_b)
    end
  end
end
