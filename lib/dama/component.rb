module Dama
  # Base class for data components. Components are pure data containers
  # with named attributes and default values. They carry no behavior.
  #
  # Example:
  #   class Transform < Dama::Component
  #     attribute :x, default: 0
  #     attribute :y, default: 0
  #   end
  class Component
    class << self
      def attribute(name, default: nil)
        attribute_set.add(name:, default:)
      end

      def attribute_set
        @attribute_set ||= AttributeSet.new(owner: self)
      end
    end

    def initialize(**values)
      self.class.attribute_set.each do |definition|
        value = values.fetch(definition.name, definition.default)
        instance_variable_set(:"@#{definition.name}", value)
      end
    end
  end
end
