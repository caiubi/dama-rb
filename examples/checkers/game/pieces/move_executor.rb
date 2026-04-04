# Applies a validated move to the board, handling captures and king promotion.
# Returns a new Board instance (the original is not mutated).
class MoveExecutor
  PROMOTION_ROWS = { red: 7, dark: 0 }.freeze

  def initialize(board:)
    @board = board
  end

  def execute(move:)
    piece = board.piece_at(position: move.from)

    updated = remove_captured_pieces(board:, captures: move.captures)
    updated = updated.remove(position: move.from)

    promoted = maybe_promote(piece:, destination: move.to)
    updated.place(position: promoted.last, piece: promoted.first)
  end

  private

  attr_reader :board

  def remove_captured_pieces(board:, captures:)
    captures.reduce(board) { |b, pos| b.remove(position: pos) }
  end

  # Returns [piece, position] — the piece may be promoted.
  def maybe_promote(piece:, destination:)
    promotion_row = PROMOTION_ROWS.fetch(piece.team)
    promoted_piece = destination.row == promotion_row ? piece.kinged : piece
    [promoted_piece, destination]
  end
end
