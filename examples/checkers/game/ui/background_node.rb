# Dark textured background behind the board for visual depth.
class BackgroundNode < Dama::Node
  BG_COLOR = Dama::Colors::Color.new(r: 0.08, g: 0.09, b: 0.10, a: 1.0)
  VIGNETTE_COLOR = Dama::Colors::Color.new(r: 0.04, g: 0.05, b: 0.06, a: 1.0)

  draw do
    # Full-screen dark background
    rect(0, 0, 800, 600, color: BG_COLOR)

    # Subtle vignette corners for depth
    rect(0, 0, 200, 150, color: VIGNETTE_COLOR)
    rect(600, 0, 200, 150, color: VIGNETTE_COLOR)
    rect(0, 450, 200, 150, color: VIGNETTE_COLOR)
    rect(600, 450, 200, 150, color: VIGNETTE_COLOR)

    # Subtle surface texture — faint horizontal lines
    12.times do |i|
      y = i * 50.0
      rect(0, y, 800, 1, r: 1.0, g: 1.0, b: 1.0, a: 0.015)
    end
  end
end
