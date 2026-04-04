# Decorative mini checkerboard pattern for the title background.
class TitleBoardNode < Dama::Node
  LIGHT = Dama::Colors::LIGHT_TAN.with_alpha(a: 0.12)
  DARK  = Dama::Colors::DARK_BROWN.with_alpha(a: 0.12)
  COLOR_BY_PARITY = { 0 => LIGHT, 1 => DARK }.freeze
  SQUARE = 75.0

  draw do
    8.times do |row|
      11.times do |col|
        color = COLOR_BY_PARITY.fetch((row + col) % 2)
        rect(col * SQUARE, row * SQUARE, SQUARE, SQUARE, color:)
      end
    end
  end
end

# Decorative checker pieces on the title screen.
class TitlePieceNode < Dama::Node
  DARK_RED = Dama::Colors::DARK_RED
  RED = Dama::Colors::RED
  SLATE = Dama::Colors::SLATE
  CHARCOAL = Dama::Colors::CHARCOAL
  HIGHLIGHT = Dama::Colors::Color.new(r: 1.0, g: 1.0, b: 1.0, a: 0.2)

  draw do
    # Red piece (left of title)
    circle(160.0, 270.0, 40.0, color: DARK_RED)
    circle(160.0, 270.0, 34.0, color: RED)
    circle(153.0, 262.0, 12.0, color: HIGHLIGHT)

    # Dark piece (right of title)
    circle(640.0, 270.0, 40.0, color: SLATE)
    circle(640.0, 270.0, 34.0, color: CHARCOAL)
    circle(633.0, 262.0, 12.0, color: HIGHLIGHT)
  end
end

class TitleTextNode < Dama::Node
  BG = Dama::Colors::Color.new(r: 0.06, g: 0.07, b: 0.08, a: 1.0)

  draw do
    # Dark background
    rect(0, 0, 800, 600, color: BG)
  end
end

class TitleLabelNode < Dama::Node
  draw do
    # Title text with subtle shadow
    text("dama-rb", 249.0, 169.0, size: 64.0, r: 0.0, g: 0.0, b: 0.0, a: 0.4)
    text("dama-rb", 247.0, 167.0, size: 64.0, color: Dama::Colors::RED)

    text("Checkers", 277.0, 259.0, size: 48.0, r: 0.0, g: 0.0, b: 0.0, a: 0.4)
    text("Checkers", 275.0, 257.0, size: 48.0, color: Dama::Colors::CREAM)

    # Decorative divider line
    rect(300.0, 320.0, 200.0, 2.0, color: Dama::Colors::DARK_BROWN)

    text("Click anywhere to start", 248.0, 360.0, size: 22.0, color: Dama::Colors::LIGHT_TAN)
  end
end

class TitleScene < Dama::Scene
  compose do
    add TitleTextNode, as: :bg
    add TitleBoardNode, as: :board_bg
    add TitlePieceNode, as: :pieces
    add TitleLabelNode, as: :labels
  end

  update do |_dt, input|
    switch_to(GameScene) if input.mouse_clicked?
  end
end
