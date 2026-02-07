module Dama
  module Backend
    # Abstract interface for rendering backends. Defines the contract
    # that all backends (native, web, etc.) must implement.
    # Each method raises NotImplementedError by default.
    class Base
      def initialize_engine(configuration:)
        raise NotImplementedError
      end

      def shutdown
        raise NotImplementedError
      end

      def poll_events
        raise NotImplementedError
      end

      def begin_frame
        raise NotImplementedError
      end

      def end_frame
        raise NotImplementedError
      end

      def delta_time
        raise NotImplementedError
      end

      def frame_count
        raise NotImplementedError
      end

      def clear(color: Dama::Colors::BLACK, r: color.r, g: color.g, b: color.b, a: color.a)
        raise NotImplementedError
      end

      def draw_triangle(x1:, y1:, x2:, y2:, x3:, y3:, color: Dama::Colors::WHITE, r: color.r, g: color.g, b: color.b, a: color.a, filled: true)
        raise NotImplementedError
      end

      def draw_rect(x:, y:, w:, h:, color: Dama::Colors::WHITE, r: color.r, g: color.g, b: color.b, a: color.a, filled: true)
        raise NotImplementedError
      end

      def draw_circle(cx:, cy:, radius:, color: Dama::Colors::WHITE, r: color.r, g: color.g, b: color.b, a: color.a, filled: true, segments: 32)
        raise NotImplementedError
      end

      def draw_text(text:, x:, y:, size:, color: Dama::Colors::WHITE, r: color.r, g: color.g, b: color.b, a: color.a)
        raise NotImplementedError
      end
    end
  end
end
