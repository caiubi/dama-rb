# Converts between pixel coordinates and board positions.
# The board origin is the top-left corner of square (0, 0).
class CoordinateConverter
  def initialize(origin_x:, origin_y:, square_size:)
    @origin_x = origin_x
    @origin_y = origin_y
    @square_size = square_size
  end

  # Converts pixel coordinates to a board Position, or nil if out of bounds.
  def to_board(pixel_x:, pixel_y:)
    col = ((pixel_x - origin_x) / square_size).floor
    row = ((pixel_y - origin_y) / square_size).floor

    return nil unless in_bounds?(row:, col:)

    Position.new(row:, col:)
  end

  # Returns the pixel center { x:, y: } of a board Position.
  def to_pixel(position:)
    half = square_size / 2.0
    x = origin_x + (position.col * square_size) + half
    y = origin_y + (position.row * square_size) + half
    { x:, y: }
  end

  private

  attr_reader :origin_x, :origin_y, :square_size

  def in_bounds?(row:, col:)
    (0...Board::ROWS).cover?(row) && (0...Board::COLS).cover?(col)
  end
end
