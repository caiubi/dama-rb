module Dama
  module SceneGraph
    # A named container in the scene graph. Holds child nodes
    # and supports polymorphic traversal.
    class GroupNode
      attr_reader :name, :children

      def initialize(name:)
        @name = name
        @children = []
      end

      def <<(node)
        children << node
      end

      def [](id)
        children.detect { |child| child.id == id }
      end

      # Polymorphic traversal: delegates to each child.
      def traverse(&)
        children.each { |child| child.traverse(&) }
      end
    end
  end
end
