module Dama
  module Physics
    # A physics body attached to a node. Tracks velocity, acceleration,
    # and collider shape. Updated by Physics::World each frame.
    class Body
      BODY_TYPES = %i[dynamic static kinematic].freeze

      attr_reader :type, :mass, :collider, :node
      attr_accessor :velocity_x, :velocity_y, :acceleration_x, :acceleration_y,
                    :restitution

      def initialize(type:, collider:, mass: 1.0, node: nil, restitution: 0.0)
        @type = type
        @mass = mass.to_f
        @collider = collider
        @node = node
        @velocity_x = 0.0
        @velocity_y = 0.0
        @acceleration_x = 0.0
        @acceleration_y = 0.0
        @restitution = restitution.to_f
      end

      def dynamic? = type == :dynamic
      def static? = type == :static
      def kinematic? = type == :kinematic

      # Current position from the node's transform component.
      def x
        node.transform.x
      end

      def y
        node.transform.y
      end

      def x=(value)
        node.transform.x = value
      end

      def y=(value)
        node.transform.y = value
      end

      # Integrate velocity and acceleration over delta_time.
      def integrate(delta_time:, gravity_x: 0.0, gravity_y: 0.0)
        return unless dynamic?

        self.velocity_x += (acceleration_x + gravity_x) * delta_time
        self.velocity_y += (acceleration_y + gravity_y) * delta_time

        self.x = x + (velocity_x * delta_time)
        self.y = y + (velocity_y * delta_time)
      end
    end
  end
end
