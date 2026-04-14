module Dama
  module SceneGraph
    # Wraps a live Node instance within the scene graph.
    # Holds the id, tags, and delegates to the underlying Node.
    class InstanceNode
      attr_reader :id, :node, :tags

      def initialize(id:, node:, tags: [])
        @id = id
        @node = node
        @tags = tags
      end

      # Polymorphic traversal: yields self to the block.
      def traverse
        yield(self)
      end

      def method_missing(method_name, ...)
        return super unless node.respond_to?(method_name)

        node.public_send(method_name, ...)
      end

      def respond_to_missing?(method_name, include_private = false)
        node.respond_to?(method_name, include_private) || super
      end
    end
  end
end
