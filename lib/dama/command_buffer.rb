module Dama
  # Accumulates high-level draw commands as compact float sequences.
  # Used by Backend::Web to minimize Ruby-side work — geometry decomposition
  # is deferred to Rust wasm via dama_render_commands.
  #
  # Each command starts with a type tag followed by shape-specific data.
  # Rust parses the tag and decomposes shapes into triangles at native speed.
  class CommandBuffer
    COMMAND_TAGS = {
      circle: 0.0,
      rect: 1.0,
      triangle: 2.0,
      sprite: 3.0,
      set_texture: 4.0,
      set_shader: 5.0,
    }.freeze

    def initialize
      @buffer = []
    end

    def push_circle(cx:, cy:, radius:, r:, g:, b:, a:, segments:)
      buffer.push(
        COMMAND_TAGS.fetch(:circle),
        cx.to_f, cy.to_f, radius.to_f,
        r.to_f, g.to_f, b.to_f, a.to_f,
        segments.to_f
      )
    end

    def push_rect(x:, y:, w:, h:, r:, g:, b:, a:)
      buffer.push(
        COMMAND_TAGS.fetch(:rect),
        x.to_f, y.to_f, w.to_f, h.to_f,
        r.to_f, g.to_f, b.to_f, a.to_f
      )
    end

    def push_triangle(x1:, y1:, x2:, y2:, x3:, y3:, r:, g:, b:, a:)
      buffer.push(
        COMMAND_TAGS.fetch(:triangle),
        x1.to_f, y1.to_f, x2.to_f, y2.to_f, x3.to_f, y3.to_f,
        r.to_f, g.to_f, b.to_f, a.to_f
      )
    end

    def push_sprite(texture_handle:, x:, y:, w:, h:, r:, g:, b:, a:, u_min:, v_min:, u_max:, v_max:) # rubocop:disable Metrics/ParameterLists
      buffer.push(
        COMMAND_TAGS.fetch(:sprite),
        texture_handle.to_f, x.to_f, y.to_f, w.to_f, h.to_f,
        r.to_f, g.to_f, b.to_f, a.to_f,
        u_min.to_f, v_min.to_f, u_max.to_f, v_max.to_f
      )
    end

    def push_set_shader(shader_handle:)
      buffer.push(
        COMMAND_TAGS.fetch(:set_shader),
        shader_handle.to_f,
      )
    end

    def empty?
      buffer.empty?
    end

    def float_count
      buffer.length
    end

    def to_a
      buffer.dup
    end

    def clear
      buffer.clear
    end

    private

    attr_reader :buffer
  end
end
