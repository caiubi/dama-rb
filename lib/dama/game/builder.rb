module Dama
  class Game
    # Evaluates the Game.new block. Provides `settings` and `start_scene`.
    class Builder
      attr_reader :configuration, :start_scene_class

      def initialize(registry:)
        @registry = registry
        @configuration = Configuration.new
        @start_scene_class = nil
      end

      def settings(resolution: [800, 600], title: "Dama Game", headless: false)
        width, height = resolution
        @configuration = Configuration.new(width:, height:, title:, headless:)
      end

      def start_scene(scene_class)
        @start_scene_class = scene_class
      end

      private

      attr_reader :registry
    end
  end
end
