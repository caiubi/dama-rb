# Dark background with subtle grid and starfield for visual depth.
class Background < Dama::Node
  BG_COLOR = { r: 0.02, g: 0.02, b: 0.06, a: 1.0 }.freeze
  GRID_COLOR = { r: 0.08, g: 0.08, b: 0.15, a: 1.0 }.freeze
  BORDER_GLOW = { r: 0.15, g: 0.25, b: 0.6, a: 0.25 }.freeze
  BORDER_BRIGHT = { r: 0.25, g: 0.4, b: 0.9, a: 0.4 }.freeze

  # Deterministic star positions (seeded once at load time)
  STARS = Array.new(40) do |i|
    # Spread stars across the screen using simple deterministic math
    x = ((i * 137 + 53) % 780) + 10.0
    y = ((i * 89 + 17) % 580) + 10.0
    brightness = (((i * 43) % 100) / 100.0) * 0.3 + 0.1
    { x:, y:, brightness: }
  end.freeze

  draw do
    # Deep dark background
    rect(0, 0, 800, 600, **BG_COLOR)

    # Subtle grid lines
    17.times do |i|
      x = i * 50.0
      rect(x, 0, 1, 600, **GRID_COLOR)
    end
    13.times do |i|
      y = i * 50.0
      rect(0, y, 800, 1, **GRID_COLOR)
    end

    # Starfield
    STARS.each do |star|
      circle(star.fetch(:x), star.fetch(:y), 1.5,
             r: 0.7, g: 0.8, b: 1.0, a: star.fetch(:brightness))
    end

    # Play area border glow (left, right, top)
    rect(0, 0, 3, 600, **BORDER_GLOW)
    rect(797, 0, 3, 600, **BORDER_GLOW)
    rect(0, 0, 800, 3, **BORDER_GLOW)

    # Brighter border edge lines
    rect(0, 0, 1, 600, **BORDER_BRIGHT)
    rect(799, 0, 1, 600, **BORDER_BRIGHT)
    rect(0, 0, 800, 1, **BORDER_BRIGHT)
  end
end
