# Finds all valid moves for a piece, including multi-jump capture chains.
# Enforces the mandatory capture rule: if any capture is available
# for any piece of the current team, only captures are returned.
class MoveFinder
  FORWARD_DIRECTIONS = {
    red: [Position.new(row: 1, col: -1), Position.new(row: 1, col: 1)],
    dark: [Position.new(row: -1, col: -1), Position.new(row: -1, col: 1)]
  }.freeze

  ALL_DIRECTIONS = [
    Position.new(row: 1, col: -1), Position.new(row: 1, col: 1),
    Position.new(row: -1, col: -1), Position.new(row: -1, col: 1)
  ].freeze

  # Maps [king] to the direction lookup strategy. Kings use all
  # directions; regular pieces use forward-only based on team.
  DIRECTION_STRATEGIES = {
    true => ->(_team) { ALL_DIRECTIONS },
    false => ->(team) { FORWARD_DIRECTIONS.fetch(team) }
  }.freeze

  OPPONENT = { red: :dark, dark: :red }.freeze

  def initialize(board:)
    @board = board
  end

  def moves_for(position:)
    piece = board.piece_at(position:)
    return [] unless piece

    directions = directions_for(piece:)
    captures = find_single_captures(position:, directions:, piece:)

    return captures if captures.any?

    find_simple_moves(position:, directions:)
  end

  # All legal moves for every piece of a team.
  def all_moves_for(team:)
    all = board.pieces_for(team:).flat_map do |position, _piece|
      moves_for(position:)
    end

    # Mandatory capture: if any move is a capture, filter to captures only.
    captures = all.select(&:capture?)
    captures.any? ? captures : all
  end

  private

  attr_reader :board

  def directions_for(piece:)
    DIRECTION_STRATEGIES.fetch(piece.king).call(piece.team)
  end

  # Returns single-step captures (one jump each).
  # Multi-jump chains are handled by the GameState: after a capture,
  # it checks if the same piece can capture again and keeps it selected.
  def find_single_captures(position:, directions:, piece:)
    opponent_team = OPPONENT.fetch(piece.team)

    directions.filter_map do |dir|
      mid = offset(position:, direction: dir)
      landing = offset(position:, direction: Position.new(row: dir.row * 2, col: dir.col * 2))

      next unless in_bounds?(position: landing)

      mid_piece = board.piece_at(position: mid)
      next unless mid_piece && mid_piece.team == opponent_team
      next unless board.piece_at(position: landing).nil?

      Move.new(from: position, to: landing, captures: [mid])
    end
  end

  def find_simple_moves(position:, directions:)
    directions.filter_map do |dir|
      target = offset(position:, direction: dir)
      next unless in_bounds?(position: target)
      next unless board.piece_at(position: target).nil?

      Move.new(from: position, to: target, captures: [])
    end
  end

  # Recursively finds all capture chains from a position.
  # Returns an array of Move objects (each potentially with multiple captures).
  def find_captures(position:, directions:, piece:, board:, captured:)
    opponent_team = OPPONENT.fetch(piece.team)

    chains = directions.flat_map do |dir|
      mid = offset(position:, direction: dir)
      landing = offset(position:, direction: Position.new(row: dir.row * 2, col: dir.col * 2))

      next [] unless in_bounds?(position: landing)

      mid_piece = board.piece_at(position: mid)
      next [] unless mid_piece && mid_piece.team == opponent_team
      next [] if captured.include?(mid)
      next [] unless board.piece_at(position: landing).nil?

      new_captured = captured + [mid]
      # Board after this jump (for recursive chain detection).
      jumped_board = board.remove(position: mid).remove(position: position).place(position: landing, piece:)

      # Recursively find further jumps from the landing position.
      further = find_captures(
        position: landing,
        directions:,
        piece:,
        board: jumped_board,
        captured: new_captured
      )

      # If there are further jumps, use those (they include this capture).
      # Otherwise, this single jump is a complete move.
      further.any? ? further : [Move.new(from: position, to: landing, captures: new_captured)]
    end

    chains
  end

  def offset(position:, direction:)
    Position.new(row: position.row + direction.row, col: position.col + direction.col)
  end

  def in_bounds?(position:)
    (0...Board::ROWS).cover?(position.row) && (0...Board::COLS).cover?(position.col)
  end
end
