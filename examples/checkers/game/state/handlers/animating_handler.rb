# Handles the :animating state — a piece is sliding to its destination.
# Waits for all tweens to complete, then finishes the animation.
class AnimatingHandler
  def initialize(game_state:)
    @game_state = game_state
  end

  def handle(delta_time:, input:)
    return if game_state.tweens.active?

    game_state.finish_animation
  end

  private

  attr_reader :game_state
end
