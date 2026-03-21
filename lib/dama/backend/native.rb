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

      def draw_text(text:, x:, y:, size:, color: Dama::Colors::WHITE, r: color.r, g: color.g, b: color.b, a: color.a, font: nil)
        vertex_batch.flush(bindings:)
        result = if font
                   bindings.dama_render_text_with_font(text, x, y, size, r, g, b, a, font)
                 else
                   bindings.dama_render_text(text, x, y, size, r, g, b, a)
                 end
        check_result(result:)
      end

      def load_font(path:)
        check_result(result: bindings.dama_font_load(path))
      end

      def draw_sprite(texture_handle:, x:, y:, w:, h:, color: Dama::Colors::WHITE, r: color.r, g: color.g, b: color.b, a: color.a)
        # Flush any untextured vertices, switch texture, push sprite, flush, reset.
        vertex_batch.flush(bindings:)
        check_result(result: bindings.dama_render_set_texture(texture_handle))
        vertex_batch.push(Geometry::Sprite.vertices(x:, y:, w:, h:, r:, g:, b:, a:))
        vertex_batch.flush(bindings:)
        check_result(result: bindings.dama_render_set_texture(0))
      end

      def load_texture(bytes:)
        ptr = FFI::MemoryPointer.new(:uint8, bytes.bytesize)
        ptr.put_bytes(0, bytes)
        handle = bindings.dama_asset_load_texture(ptr, bytes.bytesize)
        raise "Failed to load texture" if handle.zero?

        handle
      end

      def load_texture_file(path:)
        load_texture(bytes: File.binread(path))
      end

      def unload_texture(handle:)
        check_result(result: bindings.dama_asset_unload_texture(handle))
      end

      def screenshot(output_path:)
        check_result(result: bindings.dama_debug_screenshot(output_path))
      end

      def key_pressed?(key_code:)
        bindings.dama_input_key_pressed(key_code) == 1
      end

      def key_just_pressed?(key_code:)
        bindings.dama_input_key_just_pressed(key_code) == 1
      end

      def key_just_released?(key_code:)
        bindings.dama_input_key_just_released(key_code) == 1
      end

      def mouse_x
        bindings.dama_input_mouse_x
      end

      def mouse_y
        bindings.dama_input_mouse_y
      end

      def mouse_button_pressed?(button:)
        bindings.dama_input_mouse_button_pressed(button) == 1
      end

      def load_sound(path:)
        handle = bindings.dama_audio_load_sound(path)
        raise "Failed to load sound: #{bindings.dama_engine_last_error}" if handle.zero?

        handle
      end

      def play_sound(handle:, volume: 1.0, loop: false)
        looping = loop ? 1 : 0
        check_result(result: bindings.dama_audio_play_sound(handle, volume, looping))
      end

      def stop_all_sounds
        check_result(result: bindings.dama_audio_stop_all)
      end

      def unload_sound(handle:)
        check_result(result: bindings.dama_audio_unload_sound(handle))
      end

      def load_shader(source:)
        bindings.dama_shader_load(source)
      end

      def unload_shader(handle:)
        check_result(result: bindings.dama_shader_unload(handle))
      end

      def set_shader(handle:)
        # Flush pending vertices before changing shader to ensure
        # they render with the current shader, not the new one.
        vertex_batch.flush(bindings:)
        check_result(result: bindings.dama_render_set_shader(handle))
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
