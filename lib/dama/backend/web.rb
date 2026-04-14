module Dama
  module Backend
    # Web backend: runs in ruby.wasm, sends high-level draw commands
    # to the Rust wgpu wasm renderer via JavaScript bridge.
    #
    # Instead of decomposing shapes into triangles in Ruby (expensive in wasm),
    # we send compact commands (9-14 floats each) and let Rust decompose them
    # at native speed via dama_render_commands.
    class Web < Base
      def initialize
        @frame_count = 0
        @next_sound_handle = 0
        @command_buffer = CommandBuffer.new
      end

      def initialize_engine(configuration:)
        # On web, the engine is already initialized by index.html.
        # Only call dama_init if not yet ready (avoids double-init replacing shaders).
        w = configuration.width
        h = configuration.height
        ::JS.eval("if (!window.__damaReady) { window.damaWgpu.dama_init('game', #{w}, #{h}); }")
      end

      def shutdown; end
      def poll_events = false

      def begin_frame
        command_buffer.clear
        js_renderer.call(:dama_begin_frame)
      end

      def end_frame
        flush_commands
        js_renderer.call(:dama_end_frame)
        self.frame_count = frame_count + 1
      end

      def delta_time
        js_time[:delta].to_f
      end

      attr_reader :frame_count

      def clear(color: Dama::Colors::BLACK, r: color.r, g: color.g, b: color.b, a: color.a)
        js_renderer.call(:dama_clear, r, g, b, a)
      end

      def draw_triangle(x1:, y1:, x2:, y2:, x3:, y3:, color: Dama::Colors::WHITE,
                        r: color.r, g: color.g, b: color.b, a: color.a, filled: true)
        command_buffer.push_triangle(x1:, y1:, x2:, y2:, x3:, y3:, r:, g:, b:, a:)
      end

      def draw_rect(x:, y:, w:, h:, color: Dama::Colors::WHITE,
                    r: color.r, g: color.g, b: color.b, a: color.a, filled: true)
        command_buffer.push_rect(x:, y:, w:, h:, r:, g:, b:, a:)
      end

      def draw_circle(cx:, cy:, radius:, color: Dama::Colors::WHITE,
                      r: color.r, g: color.g, b: color.b, a: color.a, filled: true, segments: 32)
        command_buffer.push_circle(cx:, cy:, radius:, r:, g:, b:, a:, segments:)
      end

      def draw_text(text:, x:, y:, size:, color: Dama::Colors::WHITE,
                    r: color.r, g: color.g, b: color.b, a: color.a, font: nil)
        flush_commands
        js_renderer.call(:dama_render_text, text, x, y, size, r, g, b, a)
      end

      def draw_sprite(texture_handle:, x:, y:, w:, h:, color: Dama::Colors::WHITE,
                      r: color.r, g: color.g, b: color.b, a: color.a)
        command_buffer.push_sprite(
          texture_handle:, x:, y:, w:, h:, r:, g:, b:, a:,
          u_min: 0.0, v_min: 0.0, u_max: 1.0, v_max: 1.0
        )
      end

      def screenshot(output_path:); end

      def key_pressed?(key_code:)
        js_renderer.call(:dama_key_pressed, key_code).to_s == "true"
      end

      def key_just_pressed?(key_code:)
        js_renderer.call(:dama_key_just_pressed, key_code).to_s == "true"
      end

      def key_just_released?(key_code:)
        false
      end

      def mouse_x
        js_renderer.call(:dama_mouse_x).to_f
      end

      def mouse_y
        js_renderer.call(:dama_mouse_y).to_f
      end

      def mouse_button_pressed?(button:)
        ::JS.eval("return !!window.damaMouseButtons[#{button}]").to_s == "true"
      end

      def load_texture(bytes:)
        b64 = [bytes].pack("m0")
        js_array = ::JS.eval("return Uint8Array.from(atob('#{b64}'), c => c.charCodeAt(0))")
        from_bigint(js_renderer.call(:dama_load_texture, js_array))
      end

      def load_texture_file(path:)
        load_texture(bytes: File.binread(path))
      end

      def unload_texture(handle:)
        js_renderer.call(:dama_unload_texture, handle)
      end

      def load_sound(path:)
        self.next_sound_handle = next_sound_handle + 1

        data = File.binread(path)
        b64 = [data].pack("m0")
        ::JS.eval("window.damaSounds = window.damaSounds || {}; " \
                  "window.damaSounds[#{next_sound_handle}] = 'data:audio/wav;base64,#{b64}'")
        next_sound_handle
      end

      LOOP_JS = { true => "a.loop = true;", false => "" }.freeze

      def play_sound(handle:, volume: 1.0, loop: false)
        loop_js = LOOP_JS.fetch(loop)
        ::JS.eval("(() => { const a = new Audio(window.damaSounds[#{handle}]); " \
                  "a.volume = #{volume}; #{loop_js} a.play().catch(() => {}); })()")
      end

      def stop_all_sounds
        ::JS.eval("document.querySelectorAll('audio').forEach(a => { a.pause(); a.currentTime = 0; })")
      end

      def unload_sound(handle:)
        ::JS.eval("delete window.damaSounds[#{handle}]")
      end

      def load_font(path:); end

      def load_shader(source:)
        # Pass shader source via JS template literal to avoid ruby.wasm
        # JsValue.call data corruption. Escape backticks and backslashes.
        escaped = source.gsub("\\", "\\\\\\\\").gsub("`", "\\`")
        result = ::JS.eval("return String(window.damaWgpu.dama_shader_load(`#{escaped}`))")
        result.to_s.to_i
      end

      def unload_shader(handle:)
        js_renderer.call(:dama_shader_unload, to_bigint(handle))
      end

      def set_shader(handle:)
        # Merge shader switch INTO the next flush — don't send it separately.
        # This avoids the ruby.wasm state persistence issue between JS.eval calls.
        command_buffer.push_set_shader(shader_handle: handle)
      end

      private

      attr_reader :command_buffer, :next_sound_handle
      attr_writer :frame_count, :next_sound_handle

      def js_renderer
        ::JS.global[:damaWgpu]
      end

      def js_time
        ::JS.global[:damaTime]
      end

      # wasm-bindgen maps Rust u64 to JS BigInt.
      # Ruby integers must be converted before passing to wasm.
      def to_bigint(value)
        ::JS.eval("return BigInt(#{value})")
      end

      # Convert a JS BigInt (from wasm u64 return) to Ruby integer.
      # Uses BigInt.toString() → Ruby String#to_i for reliable conversion.
      def from_bigint(js_bigint)
        js_bigint.call(:toString).to_s.to_i
      end

      # Flush accumulated commands to Rust wasm via a single JS.eval call.
      # We pass the data as a JSON array string and construct the Float32Array
      # entirely in JS, because ruby.wasm's JsValue.call doesn't reliably pass
      # typed arrays to wasm-bindgen functions.
      def flush_commands
        return if command_buffer.empty?

        floats = command_buffer.to_a
        json = floats.map { |f| f.to_f.to_s }.join(",")
        ::JS.eval("window.damaWgpu.dama_render_commands(new Float32Array([#{json}]), #{floats.length})")
        command_buffer.clear
      end
    end
  end
end
