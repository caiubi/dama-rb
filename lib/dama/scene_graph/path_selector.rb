module Dama
  module SceneGraph
    # Resolves "group/node_id" path strings to nodes in the scene graph.
    # Uses regex with named groups to parse the path (no split per CLAUDE.md).
    class PathSelector
      SEGMENT_PATTERN = %r{\A(?<group>[^/]+)/(?<node_id>[^/]+)\z}

      def initialize(groups:)
        @groups = groups
      end

      def resolve(path:)
        match = path.match(SEGMENT_PATTERN)
        raise ArgumentError, "Invalid path format: #{path}" unless match

        group = groups.fetch(match[:group].to_sym)
        group[match[:node_id].to_sym]
      end

      private

      attr_reader :groups
    end
  end
end
