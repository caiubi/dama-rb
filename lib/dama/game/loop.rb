module Dama
  class Game
    # Main game loop. Ruby controls the cadence; the backend provides timing.
    # The loop runs: poll_events -> update -> begin_frame -> draw -> end_frame.
    class Loop
      def initialize(backend:, scene_provider:, frame_controller:, input:, scene_transition: nil)
        @backend = backend
        @scene_provider = scene_provider
        @frame_controller = frame_controller
        @input = input
        @scene_transition = scene_transition
      end

      def run
        loop do
          quit = backend.poll_events
          break if quit

          delta_time = backend.delta_time
          input.update

          current_scene.perform_update(delta_time:, input:)
          scene_transition&.call

          backend.begin_frame
          backend.clear
          current_scene.perform_draw(backend:)
          backend.end_frame

          frame_controller.tick
          break if frame_controller.frame_limit_reached?
        end
      end

      private

      attr_reader :backend, :scene_provider, :frame_controller, :input, :scene_transition

      def current_scene
        scene_provider.call
      end
    end
  end
end
