# Renders the 8x8 checkerboard grid with a wooden frame border.
class BoardNode < Dama::Node
  attribute :origin_x, default: 60.0
  attribute :origin_y, default: 20.0
  attribute :square_size, default: 70.0

  LIGHT = Dama::Colors::LIGHT_TAN
  DARK  = Dama::Colors::DARK_BROWN
  COLOR_BY_PARITY = { 0 => LIGHT, 1 => DARK }.freeze

  # Wooden frame surrounding the board
  FRAME_COLOR = Dama::Colors::Color.new(r: 0.30, g: 0.16, b: 0.07, a: 1.0)
  FRAME_HIGHLIGHT = Dama::Colors::Color.new(r: 0.52, g: 0.33, b: 0.18, a: 1.0)
  FRAME_PADDING = 12.0

  draw do
    board_width = Board::COLS * square_size
    board_height = Board::ROWS * square_size

    # Outer frame border (dark wood)
    rect(origin_x - FRAME_PADDING, origin_y - FRAME_PADDING,
         board_width + (FRAME_PADDING * 2), board_height + (FRAME_PADDING * 2),
         color: FRAME_COLOR)

    # Inner frame highlight (lighter wood edge)
    rect(origin_x - (FRAME_PADDING / 2), origin_y - (FRAME_PADDING / 2),
         board_width + FRAME_PADDING, board_height + FRAME_PADDING,
         color: FRAME_HIGHLIGHT)

    # Board squares
    Board::ROWS.times do |row|
      Board::COLS.times do |col|
        color = COLOR_BY_PARITY.fetch((row + col) % 2)
        x = origin_x + (col * square_size)
        y = origin_y + (row * square_size)
        rect(x, y, square_size, square_size, color:)
      end
    end
  end
end
