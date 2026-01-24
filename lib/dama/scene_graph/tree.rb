module Dama
  module SceneGraph
    # Root container of the scene graph. Maintains flat indexes
    # (by id, tag, class) and a hierarchy of groups for traversal.
    class Tree
      def initialize
        @root_children = []
        @id_index = {}
        @tag_index = TagIndex.new
        @class_index = ClassIndex.new
        @groups = {}
      end

      def add(instance_node:, parent_group: nil)
        target = parent_group ? groups.fetch(parent_group) : self
        target << instance_node
        id_index[instance_node.id] = instance_node
        tag_index.register(node: instance_node)
        class_index.register(node: instance_node)
      end

      def add_group(name:)
        group = GroupNode.new(name:)
        groups[name] = group
        root_children << group
        group
      end

      def <<(node)
        root_children << node
      end

      def remove(id:)
        node = id_index.delete(id)
        return unless node

        tag_index.unregister(node:)
        class_index.unregister(node:)
        remove_from_children(node:)
      end

      def query
        @query ||= Query.new(id_index:, tag_index:, class_index:, groups:)
      end

      def each_node(&)
        root_children.each { |child| child.traverse(&) }
      end

      # InstanceNode-like traversal protocol so Tree can be a container.
      def traverse(&)
        each_node(&)
      end

      private

      attr_reader :root_children, :id_index, :tag_index, :class_index, :groups

      def remove_from_children(node:)
        root_children.delete(node)
        groups.each_value { |group| group.children.delete(node) }
      end
    end
  end
end
