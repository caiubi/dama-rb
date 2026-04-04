# Handles the :piece_selected state — a piece is selected, valid moves shown.
# Player clicks a highlighted destination or elsewhere to deselect.
class PieceSelectedHandler
  def initialize(game_state:)
    @game_state = game_state
  end

  def handle(delta_time:, input:)
    return unless input.mouse_clicked?

    clicked = game_state.converter.to_board(pixel_x: input.mouse_x, pixel_y: input.mouse_y)
    return game_state.deselect unless clicked

    matching_move = game_state.valid_moves.detect { |m| m.to == clicked }
    return game_state.deselect unless matching_move

    game_state.execute_move(move: matching_move)
  end

  private

  attr_reader :game_state
end
