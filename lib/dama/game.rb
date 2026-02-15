module Dama
  # Top-level orchestrator for a Dama game.
  #
  # Example:
  #   game = Dama::Game.new do
  #     settings resolution: [1280, 720], title: "My Game"
  #     start_scene MenuScene
  #   end
  #   game.start
  class Game
    attr_reader :registry, :configuration, :backend, :asset_cache

    def initialize(&)
      @registry = Registry.new
      @builder = Game::Builder.new(registry:)
      builder.instance_eval(&)
      @configuration = builder.configuration
      @start_scene_class = builder.start_scene_class
      @backend = Backend.for
      @asset_cache = AssetCache.new(backend:)
    end

    def start
      run_game(frame_controller: Debug::FrameController.new)
    end

    # Run exactly N frames, then stop. For debugging and testing.
    def run_frames(count)
      run_game(frame_controller: Debug::FrameController.new(frame_limit: count))
    end

    def screenshot(output_path)
      screenshot_tool.capture(output_path:)
    end

    private

    attr_reader :builder, :start_scene_class, :current_scene, :pending_scene_class

    def run_game(frame_controller:)
      backend.initialize_engine(configuration:)
      load_initial_scene
      game_loop(frame_controller:).run
    ensure
      asset_cache.release_all
      backend.shutdown
    end

    def load_initial_scene
      @current_scene = build_scene(start_scene_class)
    end

    def build_scene(scene_class)
      scene = scene_class.new(
        registry:, asset_cache:, backend:,
        scene_switcher: method(:request_scene_switch)
      )
      scene.perform_compose
      scene.perform_enter
      scene
    end

    def request_scene_switch(scene_class)
      @pending_scene_class = scene_class
    end

    def apply_pending_scene_switch
      return unless pending_scene_class

      @current_scene = build_scene(pending_scene_class)
      @pending_scene_class = nil
    end

    def game_loop(frame_controller:)
      @game_loop ||= Game::Loop.new(
        backend:,
        scene_provider: -> { current_scene },
        frame_controller:,
        input: Input.new(backend:),
        scene_transition: method(:apply_pending_scene_switch),
      )
    end

    def screenshot_tool
      @screenshot_tool ||= Debug::ScreenshotTool.new(backend:)
    end
  end
end
