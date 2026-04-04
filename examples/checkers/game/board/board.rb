# Immutable 8x8 checkerboard state. Operations return new Board instances.
class Board
  ROWS = 8
  COLS = 8

  # Red starts on rows 0-2, dark on rows 5-7 (dark squares only).
  INITIAL_ROWS = {
    red: [0, 1, 2],
    dark: [5, 6, 7]
  }.freeze

  def initialize(squares: self.class.default_squares)
    @squares = squares.freeze
  end

  def piece_at(position:)
    squares.fetch(position, nil)
  end

  def place(position:, piece:)
    self.class.new(squares: squares.merge(position => piece))
  end

  def remove(position:)
    self.class.new(squares: squares.except(position))
  end

  def pieces_for(team:)
    squares.select { |_pos, piece| piece.team == team }
  end

  def all_pieces
    squares.dup
  end

  def self.default_squares
    squares = {}

    INITIAL_ROWS.each do |team, rows|
      rows.each do |row|
        COLS.times do |col|
          position = Position.new(row:, col:)
          squares[position] = Piece.new(team:, king: false) if position.dark_square?
        end
      end
    end

    squares
  end

  private

  attr_reader :squares
end
