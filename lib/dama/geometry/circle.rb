module Dama
  module Geometry
    # Decomposes a circle into a triangle fan (segments × 3 vertices).
    # Each vertex is [x, y, r, g, b, a, u, v] — 8 floats in pixel coordinates.
    class Circle
      def self.vertices(cx:, cy:, radius:, r:, g:, b:, a:, segments: 32)
        result = []
        angle_step = (2.0 * Math::PI) / segments

        segments.times do |i|
          angle1 = angle_step * i
          angle2 = angle_step * (i + 1)

          x1 = cx + (radius * Math.cos(angle1))
          y1 = cy + (radius * Math.sin(angle1))
          x2 = cx + (radius * Math.cos(angle2))
          y2 = cy + (radius * Math.sin(angle2))

          result.push(cx, cy, r, g, b, a, 0.0, 0.0,
                      x1, y1, r, g, b, a, 0.0, 0.0,
                      x2, y2, r, g, b, a, 0.0, 0.0)
        end

        result
      end
    end
  end
end
