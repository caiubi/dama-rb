module Dama
  # Holds game-wide settings like resolution, title, and rendering mode.
  # Passed to the backend to configure window and renderer initialization.
  class Configuration
    attr_reader :width, :height, :title, :headless

    def initialize(width: 800, height: 600, title: "Dama Game", headless: false)
      @width = width
      @height = height
      @title = title
      @headless = headless
    end

    def resolution
      [width, height]
    end
  end
end
