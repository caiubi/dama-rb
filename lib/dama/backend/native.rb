module Dama
  module Backend
    # Native backend: calls the Rust cdylib through ruby-ffi.
    # Shapes are decomposed into vertices in Ruby and submitted
    # as a single batch per frame via dama_render_vertices.
    class Native < Base
      HEADLESS_INIT = lambda { |bindings, config|
        bindings.dama_engine_init_headless(config.width, config.height)
      }

      # :nocov:
      WINDOWED_INIT = ->(bindings, config) { bindings.dama_engine_init(config.width, config.height, config.title) }
      # :nocov:

      INIT_STRATEGIES = { true => HEADLESS_INIT, false => WINDOWED_INIT }.freeze

      def initialize
        @bindings = Native::FfiBindings
        @vertex_batch = VertexBatch.new
      end

      def initialize_engine(configuration:)
        strategy = INIT_STRATEGIES.fetch(configuration.headless)
        result = strategy.call(bindings, configuration)
        check_result(result:)
      end

      def shutdown
        check_result(result: bindings.dama_engine_shutdown)
      end

      def poll_events
        result = bindings.dama_engine_poll_events
        result == 1
      end

      def begin_frame
        check_result(result: bindings.dama_engine_begin_frame)
      end

      def end_frame
        # Flush accumulated vertices to the GPU in one FFI call.
        vertex_batch.flush(bindings:)
        check_result(result: bindings.dama_engine_end_frame)
      end

      def delta_time
        bindings.dama_engine_delta_time
      end

      def frame_count
        bindings.dama_engine_frame_count
      end

      def clear(color: Dama::Colors::BLACK, r: color.r, g: color.g, b: color.b, a: color.a)
        check_result(result: bindings.dama_render_clear(r, g, b, a))
      end

      def draw_triangle(x1:, y1:, x2:, y2:, x3:, y3:, color: Dama::Colors::WHITE, r: color.r, g: color.g, b: color.b, a: color.a, filled: true)
        vertex_batch.push(Geometry::Triangle.vertices(x1:, y1:, x2:, y2:, x3:, y3:, r:, g:, b:, a:))
      end

      def draw_rect(x:, y:, w:, h:, color: Dama::Colors::WHITE, r: color.r, g: color.g, b: color.b, a: color.a, filled: true)
        vertex_batch.push(Geometry::Rect.vertices(x:, y:, w:, h:, r:, g:, b:, a:))
      end

      def draw_circle(cx:, cy:, radius:, color: Dama::Colors::WHITE, r: color.r, g: color.g, b: color.b, a: color.a, filled: true, segments: 32)
        vertex_batch.push(Geometry::Circle.vertices(cx:, cy:, radius:, r:, g:, b:, a:, segments:))
      end

      private

      attr_reader :bindings, :vertex_batch

      def check_result(result:)
        return if result >= 0

        error_msg = bindings.dama_engine_last_error
        raise error_msg || "Unknown native engine error"
      end
    end
  end
end
