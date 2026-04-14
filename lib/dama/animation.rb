module Dama
  # Cycles through sprite sheet frames over time.
  # Supports looping and one-shot animations.
  class Animation
    attr_reader :fps

    def initialize(frames:, fps:, loop: true, on_complete: nil)
      @frame_indices = frames.to_a
      @fps = fps.to_f
      @looping = loop
      @on_complete = on_complete
      @elapsed = 0.0
      @frame_position = 0
      @completed = false
    end

    def update(delta_time:)
      return if completed

      self.elapsed = elapsed + delta_time
      frame_duration = 1.0 / fps
      frames_advanced = (elapsed / frame_duration).to_i

      return unless frames_advanced > frame_position

      self.frame_position = frames_advanced
      handle_frame_advancement
    end

    def complete?
      completed
    end

    def reset
      self.elapsed = 0.0
      self.frame_position = 0
      self.completed = false
    end

    def current_frame
      frame_indices[frame_position % frame_indices.size]
    end

    private

    attr_reader :frame_indices, :looping, :on_complete, :elapsed, :frame_position, :completed
    attr_writer :elapsed, :frame_position, :completed

    def handle_frame_advancement
      return if frame_position < frame_indices.size

      finish_animation
    end

    FINISH_STRATEGIES = {
      true => :loop_animation,
      false => :complete_animation,
    }.freeze

    def finish_animation
      send(FINISH_STRATEGIES.fetch(looping))
    end

    def complete_animation
      self.frame_position = frame_indices.size - 1
      self.completed = true
      on_complete&.call
    end

    def loop_animation
      self.frame_position = frame_position % frame_indices.size
    end
  end
end
