module Dama
  module Physics
    # Value object representing a collision between two physics bodies.
    class Collision
      attr_reader :body_a, :body_b, :separation_x, :separation_y

      def initialize(body_a:, body_b:, separation_x:, separation_y:)
        @body_a = body_a
        @body_b = body_b
        @separation_x = separation_x
        @separation_y = separation_y
      end
    end
  end
end
