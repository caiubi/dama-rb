module Dama
  module Geometry
    # Decomposes a rectangle into 2 triangles (6 vertices).
    # Each vertex is [x, y, r, g, b, a, u, v] — 8 floats in pixel coordinates.
    class Rect
      def self.vertices(x:, y:, w:, h:, r:, g:, b:, a:)
        [x,     y,     r, g, b, a, 0.0, 0.0,
         x + w, y,     r, g, b, a, 0.0, 0.0,
         x,     y + h, r, g, b, a, 0.0, 0.0,
         x + w, y,     r, g, b, a, 0.0, 0.0,
         x + w, y + h, r, g, b, a, 0.0, 0.0,
         x,     y + h, r, g, b, a, 0.0, 0.0]
      end
    end
  end
end
