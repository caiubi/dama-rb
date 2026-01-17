module Dama
  class Component
    # Value object holding the name and default value of a component attribute.
    class AttributeDefinition
      attr_reader :name, :default

      def initialize(name:, default:)
        @name = name
        @default = default
      end
    end
  end
end
