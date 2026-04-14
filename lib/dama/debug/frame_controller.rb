module Dama
  module Debug
    # Controls frame limits for debugging. Supports two modes:
    # - Limited: stops after N frames
    # - Unlimited: runs indefinitely
    # Selected at construction time via factory (no runtime conditionals).
    class FrameController
      # Strategy lambdas selected by mode to avoid runtime conditionals.
      STRATEGIES = {
        limited: ->(current_frame, frame_limit) { current_frame >= frame_limit },
        unlimited: ->(_current_frame, _frame_limit) { false },
      }.freeze

      STRATEGY_KEYS = { true => :unlimited, false => :limited }.freeze

      def initialize(frame_limit: 0)
        @frame_limit = frame_limit
        @current_frame = 0
        @strategy_key = STRATEGY_KEYS.fetch(frame_limit.zero?)
      end

      def tick
        self.current_frame = current_frame + 1
      end

      def frame_limit_reached?
        STRATEGIES.fetch(strategy_key).call(current_frame, frame_limit)
      end

      attr_reader :current_frame

      private

      attr_reader :frame_limit, :strategy_key
      attr_writer :current_frame
    end
  end
end
