module Dama
  # Reference-counted texture cache. Textures are loaded once and shared
  # across all nodes that declare the same path. When the last node using
  # a texture is removed, the texture is unloaded from the GPU.
  class AssetCache
    def initialize(backend:)
      @backend = backend
      @entries = {}
    end

    # Acquire a texture handle for the given path. Loads from disk on first
    # use; subsequent calls increment the reference count and return the
    # same handle.
    def acquire(path:)
      entry = entries[path]

      return increment_and_return(entry) if entry

      handle = backend.load_texture_file(path:)
      entries[path] = { handle:, ref_count: 1 }
      handle
    end

    # Release one reference to the texture at the given path. When the
    # reference count reaches zero, the texture is unloaded from the GPU.
    def release(path:)
      entry = entries[path]
      return unless entry

      entry[:ref_count] -= 1
      return unless entry[:ref_count] <= 0

      backend.unload_texture(handle: entry.fetch(:handle))
      entries.delete(path)
    end

    # Release all textures regardless of reference count.
    def release_all
      entries.each_value { |entry| backend.unload_texture(handle: entry.fetch(:handle)) }
      entries.clear
    end

    def handle_for(path:)
      entries.dig(path, :handle)
    end

    private

    attr_reader :backend, :entries

    def increment_and_return(entry)
      entry[:ref_count] += 1
      entry.fetch(:handle)
    end
  end
end
