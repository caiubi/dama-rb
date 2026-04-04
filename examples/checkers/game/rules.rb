# Checks win conditions and determines the game winner.
class Rules
  OPPONENT = { red: :dark, dark: :red }.freeze

  def initialize(board:)
    @board = board
  end

  # Returns :red, :dark, or nil (game in progress).
  def winner(current_team:)
    return opponent_of(current_team) if no_pieces?(current_team)
    return opponent_of(current_team) if no_moves?(current_team)

    nil
  end

  private

  attr_reader :board

  def opponent_of(team)
    OPPONENT.fetch(team)
  end

  def no_pieces?(team)
    board.pieces_for(team:).empty?
  end

  def no_moves?(team)
    MoveFinder.new(board:).all_moves_for(team:).empty?
  end
end
