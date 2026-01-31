module Dama
  module Geometry
    # Decomposes a triangle into 3 vertices.
    # Each vertex is [x, y, r, g, b, a, u, v] — 8 floats in pixel coordinates.
    class Triangle
      def self.vertices(x1:, y1:, x2:, y2:, x3:, y3:, r:, g:, b:, a:)
        [x1, y1, r, g, b, a, 0.0, 0.0,
         x2, y2, r, g, b, a, 0.0, 0.0,
         x3, y3, r, g, b, a, 0.0, 0.0]
      end
    end
  end
end
