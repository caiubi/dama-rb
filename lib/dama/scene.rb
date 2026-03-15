module Dama
  # Base class for game scenes. Scenes have a compose/enter/update
  # lifecycle and manage a scene graph of nodes.
  #
  # Example:
  #   class Level1 < Dama::Scene
  #     sound :jump, path: "assets/sfx/jump.wav"
  #
  #     compose do
  #       camera viewport_width: 800, viewport_height: 600
  #       add Player, as: :hero
  #     end
  #
  #     update do |dt, input|
  #       hero.transform.x += 100 * dt if input.right?
  #       play(:jump) if input.space?
  #     end
  #   end
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

      # Declare a sound asset at the class level.
      # Loaded automatically during scene composition.
      def sound(name, path:)
        sound_declarations[name] = path
      end

      def sound_declarations
        @sound_declarations ||= {}
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
      @audio = nil
      @physics_world = nil
      @collision_handlers = {}
    end

    # Play a sound declared via the `sound` class DSL.
    def play(name)
      audio&.play(name)
    end

    def enable_camera(viewport_width:, viewport_height:, **)
      @camera = Camera.new(viewport_width:, viewport_height:, **)
    end

    # Enable physics for this scene. Called by `physics` DSL in composer.
    def enable_physics(gravity_x: 0.0, gravity_y: 0.0)
      event_bus = EventBus.new
      @physics_world = Physics::World.new(gravity_x:, gravity_y:, event_bus:)

      # Wire collision events to named handlers.
      event_bus.on(:collision) do |collision:|
        dispatch_collision(collision)
      end
    end

    # Register a collision handler between two named nodes.
    def on_collision(name_a, name_b, &block)
      key = [name_a, name_b].sort
      collision_handlers[key] = block
    end

    # Request a scene transition. The game applies it between frames.
    def switch_to(scene_class)
      scene_switcher&.call(scene_class)
    end

    def perform_compose
      load_sounds
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
      physics_world&.step(delta_time:)
    end

    def perform_draw(backend:)
      scene_graph.each_node do |instance_node|
        draw_block = instance_node.node.class.draw_block
        next unless draw_block

        context = Node::DrawContext.new(node: instance_node.node, backend:, camera:)
        context.instance_eval(&draw_block)
      end
    end

    # Register a named node, load textures, and create physics body.
    def register_named_node(name:, instance_node:)
      named_nodes[name] = instance_node
      define_singleton_method(name) { named_nodes.fetch(name) }

      instance_node.node.load_textures(asset_cache:) if asset_cache
      create_physics_body(name:, node: instance_node.node)
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
                :scene_switcher, :backend, :audio, :physics_world,
                :collision_handlers

    # Load all class-level sound declarations via Audio.
    def load_sounds
      return if self.class.sound_declarations.empty?
      return unless backend

      @audio = Audio.new(backend:)
      self.class.sound_declarations.each do |name, path|
        audio.load(name:, path:)
      end
    end

    COLLIDER_FACTORIES = {
      rect: ->(opts) { Physics::Collider.rect(width: opts.fetch(:width), height: opts.fetch(:height)) },
      circle: ->(opts) { Physics::Collider.circle(radius: opts.fetch(:radius)) },
    }.freeze

    # Create a physics body for a node if it declares `physics_body`.
    def create_physics_body(name:, node:)
      opts = node.class.physics_body_options
      return unless opts && physics_world

      collider_shape = opts.fetch(:collider, :rect)
      collider = COLLIDER_FACTORIES.fetch(collider_shape).call(opts)
      body = Physics::Body.new(
        type: opts.fetch(:type, :dynamic),
        mass: opts.fetch(:mass, 1.0),
        collider:,
        node:,
        restitution: opts.fetch(:restitution, 0.0),
      )
      node.physics = body
      physics_world.add(body)
    end

    # Route a collision event to the appropriate named handler.
    def dispatch_collision(collision)
      # Find node names for the two bodies.
      name_a = named_nodes.key(named_nodes.values.find { |n| n.node == collision.body_a.node })
      name_b = named_nodes.key(named_nodes.values.find { |n| n.node == collision.body_b.node })
      return unless name_a && name_b

      key = [name_a, name_b].sort
      handler = collision_handlers[key]
      handler&.call
    end
  end
end
