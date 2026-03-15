module Dama
  # High-level audio interface for loading and playing sounds.
  # Manages sound handles with reference counting (like AssetCache).
  #
  # Usage in a Node:
  #   sound :jump, path: "assets/jump.wav"
  #
  # Usage in update:
  #   Audio.play(:jump)
  #   Audio.play(:theme, volume: 0.5, loop: true)
  class Audio
    attr_reader :backend

    def initialize(backend:)
      @backend = backend
      @sounds = {}
    end

    def load(name:, path:)
      handle = backend.load_sound(path:)
      sounds[name] = handle
    end

    def play(name, volume: 1.0, loop: false)
      handle = sounds.fetch(name)
      backend.play_sound(handle:, volume:, loop:)
    end

    def stop_all
      backend.stop_all_sounds
    end

    def unload(name)
      handle = sounds.delete(name)
      backend.unload_sound(handle:) if handle
    end

    def unload_all
      sounds.each_value { |handle| backend.unload_sound(handle:) }
      sounds.clear
    end

    private

    attr_reader :sounds
  end
end
