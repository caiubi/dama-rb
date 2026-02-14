module Dama
  # Base class for game scenes. Scenes have a compose/enter/update
  # lifecycle and manage a scene graph of nodes.
  class Scene
    class << self
      def compose(&block)
        @compose_block = block
      end

      def enter(&block)
        @enter_block = block
      end

      def update(&block)
        @update_block = block
      end

      attr_reader :compose_block, :enter_block, :update_block
    end

    attr_reader :camera

    def initialize(registry:, asset_cache: nil, scene_switcher: nil, backend: nil)
      @registry = registry
      @asset_cache = asset_cache
      @scene_switcher = scene_switcher
      @backend = backend
      @scene_graph = SceneGraph::Tree.new
      @named_nodes = {}
      @camera = nil
    end

    def enable_camera(viewport_width:, viewport_height:, **)
      @camera = Camera.new(viewport_width:, viewport_height:, **)
    end

    # Request a scene transition. The game applies it between frames.
    def switch_to(scene_class)
      scene_switcher&.call(scene_class)
    end

    def perform_compose
      return unless self.class.compose_block

      composer = Scene::Composer.new(scene_graph:, registry:, scene: self)
      composer.instance_eval(&self.class.compose_block)
    end

    def perform_enter
      return unless self.class.enter_block

      instance_eval(&self.class.enter_block)
    end

    def perform_update(delta_time:, input:)
      instance_exec(delta_time, input, &self.class.update_block) if self.class.update_block
    end

    def perform_draw(backend:)
      scene_graph.each_node do |instance_node|
        draw_block = instance_node.node.class.draw_block
        next unless draw_block

        context = Node::DrawContext.new(node: instance_node.node, backend:, camera:)
        context.instance_eval(&draw_block)
      end
    end

    # Register a named node and load textures.
    def register_named_node(name:, instance_node:)
      named_nodes[name] = instance_node
      define_singleton_method(name) { named_nodes.fetch(name) }

      instance_node.node.load_textures(asset_cache:) if asset_cache
    end

    # --- Query methods ---

    def ref!(path)
      scene_graph.query.by_path(path:)
    end

    def all(klass)
      scene_graph.query.by_class(klass:)
    end

    def by_tag(tag)
      scene_graph.query.by_tag(tag:)
    end

    def each(klass, &)
      all(klass).each(&)
    end

    private

    attr_reader :registry, :scene_graph, :named_nodes, :asset_cache,
                :scene_switcher, :backend
  end
end
