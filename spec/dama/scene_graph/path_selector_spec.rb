RSpec.describe Dama::SceneGraph::PathSelector do
  subject(:selector) { described_class.new(groups: { ui: group }) }

  let(:node_class) { Class.new(Dama::Node) }
  let(:hud_node) { Dama::SceneGraph::InstanceNode.new(id: :hud, node: node_class.new) }

  let(:group) do
    group = Dama::SceneGraph::GroupNode.new(name: :ui)
    group << hud_node
    group
  end

  describe "#resolve" do
    it "resolves a 'group/node_id' path to the correct node" do
      expect(selector.resolve(path: "ui/hud")).to eq(hud_node)
    end

    it "raises ArgumentError for invalid path format" do
      expect { selector.resolve(path: "invalid") }.to raise_error(ArgumentError, /Invalid path format/)
    end
  end
end
