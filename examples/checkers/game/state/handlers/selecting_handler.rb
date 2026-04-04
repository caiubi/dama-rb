# Handles the :selecting state — waiting for the player to click a piece.
class SelectingHandler
  def initialize(game_state:)
    @game_state = game_state
  end

  def handle(delta_time:, input:)
    return unless input.mouse_clicked?

    position = game_state.converter.to_board(pixel_x: input.mouse_x, pixel_y: input.mouse_y)
    return unless position

    piece = game_state.board.piece_at(position:)
    return unless piece
    return unless piece.team == game_state.current_team

    finder = MoveFinder.new(board: game_state.board)
    moves = finder.moves_for(position:)

    all_team_moves = finder.all_moves_for(team: game_state.current_team)
    team_has_captures = all_team_moves.any?(&:capture?)
    moves = moves.select(&:capture?) if team_has_captures

    return unless moves.any?

    game_state.select_piece(position:, moves:)
  end

  private

  attr_reader :game_state
end
