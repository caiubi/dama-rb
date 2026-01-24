module Dama
  module SceneGraph
    # Indexes scene graph nodes by their tags for fast lookup.
    class TagIndex
      def initialize
        @index = Hash.new { |h, k| h[k] = [] }
      end

      def register(node:)
        node.tags.each { |tag| index[tag] << node }
      end

      def unregister(node:)
        node.tags.each { |tag| index[tag].delete(node) }
      end

      def by_tag(tag:)
        index.fetch(tag, [])
      end

      private

      attr_reader :index
    end
  end
end
