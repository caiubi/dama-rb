module Dama
  class Scene
    # Evaluates compose blocks to build the scene graph.
    # Supports multiple forms of `add`:
    #   add PlayerClass, as: :hero           # by Class
    #   add :player, as: :hero               # by Symbol (auto-discover)
    #   add "player", as: :hero              # by String (auto-discover)
    #   add Player.new, as: :hero            # by Instance
    #   add Player, as: :hero, tags: [:enemy] # with explicit tags
    class Composer
      RESOLVE_STRATEGIES = {
        Symbol => ->(name, registry) { registry.resolve(name:, category: :node) },
        String => ->(name, registry) { registry.resolve(name: name.to_sym, category: :node) },
      }.freeze

      def initialize(scene_graph:, registry:, scene:)
        @scene_graph = scene_graph
        @registry = registry
        @scene = scene
        @current_group = nil
      end

      def add(class_or_name_or_instance, as:, tags: [], **props, &block)
        node_instance = resolve_and_build(class_or_name_or_instance, props)
        instance_node = SceneGraph::InstanceNode.new(id: as, node: node_instance, tags:)
        scene_graph.add(instance_node:, parent_group: current_group)

        # Register the named accessor on the scene so `hero` works in update/enter.
        scene.register_named_node(name: as, instance_node:)

        instance_node.instance_eval(&block) if block
      end

      def camera(**)
        scene.enable_camera(**)
      end

      def physics(gravity: [0.0, 0.0])
        gravity_x, gravity_y = gravity
        scene.enable_physics(gravity_x:, gravity_y:)
      end

      def group(name, &)
        scene_graph.add_group(name:)
        previous_group = current_group
        @current_group = name
        instance_eval(&)
        @current_group = previous_group
      end

      private

      attr_reader :scene_graph, :registry, :scene, :current_group

      def resolve_and_build(class_or_name_or_instance, props)
        return class_or_name_or_instance if class_or_name_or_instance.is_a?(Dama::Node)

        return class_or_name_or_instance.new(**props) if class_or_name_or_instance.is_a?(Class)

        strategy = RESOLVE_STRATEGIES.fetch(class_or_name_or_instance.class)
        klass = strategy.call(class_or_name_or_instance, registry)
        klass.new(**props)
      end
    end
  end
end
