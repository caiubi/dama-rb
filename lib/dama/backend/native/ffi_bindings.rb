require "ffi"

module Dama
  module Backend
    class Native
      # Raw FFI bindings to the Rust cdylib. This is the only place in the
      # Ruby codebase where FFI types appear. All other code interacts
      # through the Backend::Native adapter.
      module FfiBindings
        extend FFI::Library

        # Platform-specific shared library extension, resolved via hash
        # lookup to avoid conditionals (per project coding guidelines).
        LIBRARY_EXTENSIONS = {
          "darwin" => "dylib",
          "linux" => "so",
          "mingw" => "dll",
          "mswin" => "dll",
        }.freeze

        # Library resolution order:
        # 1. DAMA_NATIVE_LIB env var — packaged games set this to their bundled copy
        # 2. lib/dama/native/ — pre-compiled platform gems and source gem extconf.rb
        #    install the shared library here
        # 3. ext/dama_native/target/release/ — local development with cargo build
        LIBRARY_PATH_RESOLVERS = [
          lambda {
            path = ENV.fetch("DAMA_NATIVE_LIB", nil)
            path if path && File.exist?(path)
          },
          lambda {
            platform_key = LIBRARY_EXTENSIONS.keys.detect { |k| RUBY_PLATFORM.include?(k) }
            extension = LIBRARY_EXTENSIONS.fetch(platform_key)
            path = File.expand_path("../../native/libdama_native.#{extension}", __dir__)
            path if File.exist?(path)
          },
          lambda {
            platform_key = LIBRARY_EXTENSIONS.keys.detect { |k| RUBY_PLATFORM.include?(k) }
            extension = LIBRARY_EXTENSIONS.fetch(platform_key)
            path = File.expand_path("../../../../ext/dama_native/target/release/libdama_native.#{extension}", __dir__)
            path if File.exist?(path)
          },
        ].freeze

        def self.library_path
          LIBRARY_PATH_RESOLVERS.each do |resolver|
            path = resolver.call
            return path if path
          end

          raise "dama native library not found. Run `cargo build --release` in ext/dama_native/ " \
                "or install a platform-specific gem."
        end

        ffi_lib library_path

        # --- Lifecycle ---
        attach_function :dama_engine_init_headless, %i[uint32 uint32], :int32
        attach_function :dama_engine_init, %i[uint32 uint32 string], :int32
        attach_function :dama_engine_shutdown, [], :int32
        attach_function :dama_engine_poll_events, [], :int32
        attach_function :dama_engine_begin_frame, [], :int32
        attach_function :dama_engine_end_frame, [], :int32
        attach_function :dama_engine_delta_time, [], :double
        attach_function :dama_engine_frame_count, [], :uint64
        attach_function :dama_engine_last_error, [], :string

        # --- Rendering ---
        attach_function :dama_render_clear, %i[float float float float], :int32
        attach_function :dama_render_vertices, %i[pointer uint32], :int32
        attach_function :dama_render_set_texture, [:uint64], :int32
        attach_function :dama_render_text,
                        %i[string float float float
                           float float float float], :int32

        # --- Assets ---
        attach_function :dama_asset_load_texture, %i[pointer uint32], :uint64
        attach_function :dama_asset_unload_texture, [:uint64], :int32

        # --- Input ---
        attach_function :dama_input_key_pressed, [:uint32], :int32
        attach_function :dama_input_key_just_pressed, [:uint32], :int32
        attach_function :dama_input_key_just_released, [:uint32], :int32
        attach_function :dama_input_mouse_x, [], :float
        attach_function :dama_input_mouse_y, [], :float
        attach_function :dama_input_mouse_button_pressed, [:uint32], :int32

        # --- Debug ---
        attach_function :dama_debug_screenshot, [:string], :int32

        # --- Fonts ---
        attach_function :dama_font_load, [:string], :int32
        attach_function :dama_render_text_with_font,
                        %i[string float float float
                           float float float float string], :int32

        # --- Audio ---
        attach_function :dama_audio_load_sound, [:string], :uint64
        attach_function :dama_audio_play_sound, %i[uint64 float int32], :int32
        attach_function :dama_audio_stop_all, [], :int32
        attach_function :dama_audio_unload_sound, [:uint64], :int32

        # --- Shaders ---
        attach_function :dama_shader_load, [:string], :uint64
        attach_function :dama_shader_unload, [:uint64], :int32
        attach_function :dama_render_set_shader, [:uint64], :int32
      end
    end
  end
end
