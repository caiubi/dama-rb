require "ffi"

module Dama
  # Accumulates vertex data per frame and flushes it to the Rust backend
  # in a single FFI call. Each vertex is 8 floats: [x, y, r, g, b, a, u, v].
  class VertexBatch
    FLOATS_PER_VERTEX = 8

    def initialize
      @buffer = []
    end

    def push(vertex_floats:)
      buffer.concat(vertex_floats)
    end

    def vertex_count
      buffer.length / FLOATS_PER_VERTEX
    end

    def flush(bindings:)
      count = vertex_count
      return if count.zero?

      ptr = FFI::MemoryPointer.new(:float, buffer.length)
      ptr.write_array_of_float(buffer)
      bindings.dama_render_vertices(ptr, count)
      buffer.clear
    end

    private

    attr_reader :buffer
  end
end
