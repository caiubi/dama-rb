module Dama
  module SceneGraph
    # Unified query API for the scene graph. Provides by_id, by_class,
    # by_tag, and by_path lookups.
    class Query
      def initialize(id_index:, tag_index:, class_index:, groups:)
        @id_index = id_index
        @tag_index = tag_index
        @class_index = class_index
        @path_selector = PathSelector.new(groups:)
      end

      def by_id(id:)
        id_index.fetch(id)
      end

      def by_class(klass:)
        class_index.by_class(klass:)
      end

      def by_tag(tag:)
        tag_index.by_tag(tag:)
      end

      def by_path(path:)
        path_selector.resolve(path:)
      end

      private

      attr_reader :id_index, :tag_index, :class_index, :path_selector
    end
  end
end
