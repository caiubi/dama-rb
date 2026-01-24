module Dama
  module SceneGraph
    # Indexes scene graph nodes by their Node class for fast lookup.
    class ClassIndex
      def initialize
        @index = Hash.new { |h, k| h[k] = [] }
      end

      def register(node:)
        index[node.node.class] << node
      end

      def unregister(node:)
        index[node.node.class].delete(node)
      end

      def by_class(klass:)
        index.fetch(klass, [])
      end

      private

      attr_reader :index
    end
  end
end
