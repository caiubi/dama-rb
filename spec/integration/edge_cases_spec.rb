RSpec.describe "Edge cases end-to-end" do
  include_context "with headless backend"

  let(:registry) { Dama::Registry.new }

  describe "Scene with no lifecycle blocks" do
    let(:empty_scene_class) { Class.new(Dama::Scene) }

    it "safely handles perform_compose/enter/update/draw on a bare scene" do
      scene = empty_scene_class.new(registry:)

      expect { scene.perform_compose }.not_to raise_error
      expect { scene.perform_enter }.not_to raise_error
      expect { scene.perform_update(delta_time: 0.016, input: Dama::Input.new(backend:)) }
        .not_to raise_error

      backend.begin_frame
      expect { scene.perform_draw(backend:) }.not_to raise_error
      backend.end_frame
    end
  end

  describe "Node without a draw block" do
    let(:data_node_class) do
      stub_const("DataNode", Class.new(Dama::Node) do
        attribute :value, default: 42
      end)
    end

    let(:drawable_node_class) do
      stub_const("DrawableNode", Class.new(Dama::Node) do
        draw do
          rect(0, 0, 10, 10, r: 1.0, g: 0.0, b: 0.0, a: 1.0)
        end
      end)
    end

    let(:scene_class) do
      dn = data_node_class
      dr = drawable_node_class
      Class.new(Dama::Scene) do
        compose do
          add dn, as: :data
          add dr, as: :visual
        end
      end
    end

    before do
      registry.register(klass: data_node_class, category: :node)
      registry.register(klass: drawable_node_class, category: :node)
    end

    it "skips nodes without draw blocks during perform_draw" do
      scene = scene_class.new(registry:)
      scene.perform_compose

      backend.begin_frame
      expect { scene.perform_draw(backend:) }.not_to raise_error
      backend.end_frame
    end
  end

  describe "Scene#remove with asset_cache on unknown node" do
    it "handles removing a name that was never added" do
      asset_cache = Dama::AssetCache.new(backend:)
      scene = Dama::Scene.new(registry:, asset_cache:)
      expect { scene.remove(:nonexistent) }.not_to raise_error
    end
  end

  describe "Wireframe rendering (filled: false)" do
    it "passes filled=false to triangle, rect, and circle" do
      backend.begin_frame
      expect do
        backend.draw_triangle(
          x1: 10.0, y1: 10.0, x2: 50.0, y2: 10.0, x3: 30.0, y3: 50.0,
          r: 1.0, g: 0.0, b: 0.0, a: 1.0, filled: false
        )
        backend.draw_rect(x: 10.0, y: 10.0, w: 40.0, h: 40.0,
                          r: 0.0, g: 1.0, b: 0.0, a: 1.0, filled: false)
        backend.draw_circle(cx: 32.0, cy: 32.0, radius: 20.0,
                            r: 0.0, g: 0.0, b: 1.0, a: 1.0, filled: false)
      end.not_to raise_error
      backend.end_frame
    end
  end

  describe "Removing a nonexistent node" do
    it "safely handles removing a name that was never added" do
      tree = Dama::SceneGraph::Tree.new
      expect { tree.remove(id: :nonexistent) }.not_to raise_error
    end
  end

  describe "InstanceNode method_missing delegation" do
    let(:node_class) do
      Class.new(Dama::Node) { attribute :name, default: "test" }
    end

    it "delegates known methods to the underlying node" do
      instance = Dama::SceneGraph::InstanceNode.new(id: :a, node: node_class.new)
      expect(instance.name).to eq("test")
    end

    it "raises NoMethodError for methods the node doesn't have" do
      instance = Dama::SceneGraph::InstanceNode.new(id: :a, node: node_class.new)
      expect { instance.nonexistent_method }.to raise_error(NoMethodError)
    end
  end

  describe "Composer add with a block" do
    let(:node_class) do
      stub_const("BlockNode", Class.new(Dama::Node) do
        attribute :label, default: "before"
      end)
    end

    before { registry.register(klass: node_class, category: :node) }

    it "evaluates the block on the instance node" do
      scene = Dama::Scene.new(registry:)
      tree = Dama::SceneGraph::Tree.new
      composer = Dama::Scene::Composer.new(scene_graph: tree, registry:, scene:)

      composer.add(node_class, as: :test) do
        node.label = "after"
      end

      expect(tree.query.by_id(id: :test).label).to eq("after")
    end
  end

  describe "Anonymous class registration" do
    it "handles classes without a name" do
      anon_class = Class.new(Dama::Node)
      expect { registry.register(klass: anon_class, category: :node) }.not_to raise_error
    end
  end
end
