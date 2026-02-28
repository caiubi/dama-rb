module Dama
  module Geometry
    # Decomposes a textured sprite quad into 2 triangles (6 vertices).
    # Each vertex is [x, y, r, g, b, a, u, v] — 8 floats in pixel coordinates.
    # UV maps the full texture (0,0)→(1,1) by default; override for atlas sub-regions.
    class Sprite
      def self.vertices(x:, y:, w:, h:, r: 1.0, g: 1.0, b: 1.0, a: 1.0,
                        u_min: 0.0, v_min: 0.0, u_max: 1.0, v_max: 1.0)
        [x,     y,     r, g, b, a, u_min, v_min,
         x + w, y,     r, g, b, a, u_max, v_min,
         x,     y + h, r, g, b, a, u_min, v_max,
         x + w, y,     r, g, b, a, u_max, v_min,
         x + w, y + h, r, g, b, a, u_max, v_max,
         x,     y + h, r, g, b, a, u_min, v_max]
      end
    end
  end
end
