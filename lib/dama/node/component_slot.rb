module Dama
  class Node
    # Binds a Component class to its default attribute values.
    # When a Node is instantiated, each slot builds a component instance.
    class ComponentSlot
      attr_reader :component_class, :defaults

      def initialize(component_class:, defaults:)
        @component_class = component_class
        @defaults = defaults
      end

      def build(**overrides)
        component_class.new(**defaults, **overrides)
      end
    end
  end
end
