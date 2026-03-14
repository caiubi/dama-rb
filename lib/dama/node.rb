module Dama
  # Base class for game entities. Nodes compose Components via named
  # accessors, declare attributes, textures, and define draw behavior.
  #
  # Example:
  #   class Player < Dama::Node
  #     component Transform, as: :transform, x: 50.0, y: 50.0
  #     texture :sprite, path: "assets/player.png"
  #     attribute :name, default: "Player"
  #
  #     draw do
  #       sprite(sprite, transform.x, transform.y, 32, 32)
  #     end
  #   end
  class Node
    class << self
      def component(component_class, as:, **defaults)
        component_slots[as] = ComponentSlot.new(component_class:, defaults:)
        define_method(as) { components.fetch(as) }
      end

      def attribute(name, default: nil)
        attribute_definitions[name] = default
        attr_accessor name
      end

      # Declare a texture asset with a named accessor.
      # The texture is loaded via AssetCache during scene composition
      # and the GPU handle is accessible as a method on the node.
      def texture(name, path:)
        texture_declarations[name] = path
        define_method(name) { texture_handles.fetch(name) }
      end

      def draw(&block)
        @draw_block = block
      end

      def component_slots
        @component_slots ||= {}
      end

      def attribute_definitions
        @attribute_definitions ||= {}
      end

      def texture_declarations
        @texture_declarations ||= {}
      end

      # Declare a physics body for this node.
      # The body is created during scene composition if the scene has physics enabled.
      def physics_body(**options)
        @physics_body_options = options
      end

      attr_reader :physics_body_options, :draw_block
    end

    attr_accessor :physics

    def initialize(**values)
      @components = {}
      @texture_handles = {}
      @physics = nil
      initialize_components(values)
      initialize_attributes(values)
    end

    # Load all declared textures via the AssetCache.
    def load_textures(asset_cache:)
      self.class.texture_declarations.each do |name, path|
        texture_handles[name] = asset_cache.acquire(path:)
      end
    end

    # Release all declared textures from the AssetCache.
    def unload_textures(asset_cache:)
      self.class.texture_declarations.each_value do |path|
        asset_cache.release(path:)
      end
      texture_handles.clear
    end

    private

    attr_reader :components, :texture_handles

    def initialize_components(values)
      self.class.component_slots.each do |name, slot|
        # Allow constructor values to override component defaults.
        # e.g., PieceNode.new(x: 100.0) overrides Transform's default x.
        component_attrs = slot.component_class.attribute_set.map(&:name)
        overrides = values.slice(*component_attrs)
        components[name] = slot.build(**overrides)
      end
    end

    def initialize_attributes(values)
      self.class.attribute_definitions.each do |name, default|
        value = values.fetch(name, default)
        public_send(:"#{name}=", value)
      end
    end
  end
end
