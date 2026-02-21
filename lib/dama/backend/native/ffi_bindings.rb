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

        def self.library_path
          platform_key = LIBRARY_EXTENSIONS.keys.detect { |k| RUBY_PLATFORM.include?(k) }
          extension = LIBRARY_EXTENSIONS.fetch(platform_key)
          File.expand_path("../../../../ext/dama_native/target/release/libdama_native.#{extension}", __dir__)
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

        # --- Input ---
        attach_function :dama_input_key_pressed, [:uint32], :int32
        attach_function :dama_input_key_just_pressed, [:uint32], :int32
        attach_function :dama_input_key_just_released, [:uint32], :int32
        attach_function :dama_input_mouse_x, [], :float
        attach_function :dama_input_mouse_y, [], :float
        attach_function :dama_input_mouse_button_pressed, [:uint32], :int32
      end
    end
  end
end
