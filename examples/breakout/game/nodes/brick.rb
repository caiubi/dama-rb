# A breakable brick with a bold 3D gem visual style.
# Thick bevels and a radial center glow shader create a "lit from within" look.
class Brick < Dama::Node
  WIDTH = 70.0
  HEIGHT = 24.0
  BEVEL = 3.0

  component Transform, as: :transform
  shader :glow, path: File.join(__dir__, "../../assets/shaders/brick_glow.wgsl")

  attribute :color_r, default: 1.0
  attribute :color_g, default: 0.0
  attribute :color_b, default: 0.0
  attribute :hits, default: 1

  draw do
    x = transform.x
    y = transform.y

    # 1. Dark border frame — separates bricks visually
    rect(x, y, WIDTH, HEIGHT, r: 0.0, g: 0.0, b: 0.0, a: 0.6)

    # 2. Bright top + left bevel (light catching edge)
    rect(x + 1.0, y + 1.0, WIDTH - 2.0, BEVEL,
         r: color_r * 0.5 + 0.5, g: color_g * 0.5 + 0.5, b: color_b * 0.5 + 0.5, a: 1.0)
    rect(x + 1.0, y + 1.0, BEVEL, HEIGHT - 2.0,
         r: color_r * 0.4 + 0.6, g: color_g * 0.4 + 0.6, b: color_b * 0.4 + 0.6, a: 1.0)

    # 3. Dark bottom + right bevel (shadow edge)
    rect(x + 1.0, y + HEIGHT - 1.0 - BEVEL, WIDTH - 2.0, BEVEL,
         r: color_r * 0.35, g: color_g * 0.35, b: color_b * 0.35, a: 1.0)
    rect(x + WIDTH - 1.0 - BEVEL, y + 1.0, BEVEL, HEIGHT - 2.0,
         r: color_r * 0.4, g: color_g * 0.4, b: color_b * 0.4, a: 1.0)

    # 4. Inner gem face — the main colored area with radial glow shader
    rect(x + BEVEL + 1.0, y + BEVEL + 1.0,
         WIDTH - (BEVEL * 2) - 2.0, HEIGHT - (BEVEL * 2) - 2.0,
         r: color_r, g: color_g, b: color_b, a: 1.0,
         shader: glow)

    # 5. Specular highlight — bright spot near top-left of inner face
    rect(x + BEVEL + 3.0, y + BEVEL + 2.0, 14.0, 3.0,
         r: 1.0, g: 1.0, b: 1.0, a: 0.45)
  end
end
