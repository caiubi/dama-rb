module Dama
  class Component
    # Collection of attribute definitions for a Component subclass.
    # Handles registration, lookup, and dynamic accessor generation
    # on the owning class.
    class AttributeSet
      include Enumerable

      def initialize(owner:)
        @owner = owner
        @definitions = {}
      end

      def add(name:, default:)
        definitions[name] = AttributeDefinition.new(name:, default:)
        owner.attr_accessor(name)
      end

      def each(&)
        definitions.values.each(&)
      end

      def fetch(name)
        definitions.fetch(name)
      end

      private

      attr_reader :owner, :definitions
    end
  end
end
