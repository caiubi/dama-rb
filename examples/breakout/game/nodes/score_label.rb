# HUD text showing score and lives with styled panel background.
class ScoreLabel < Dama::Node
  component Transform, as: :transform, x: 10.0, y: 8.0
  attribute :score, default: 0
  attribute :lives, default: 3

  PANEL_BG = { r: 0.05, g: 0.05, b: 0.12, a: 0.75 }.freeze
  PANEL_BORDER = { r: 0.2, g: 0.3, b: 0.6, a: 0.4 }.freeze
  SCORE_COLOR = { r: 1.0, g: 1.0, b: 1.0, a: 1.0 }.freeze
  LIVES_COLOR = { r: 0.4, g: 0.8, b: 1.0, a: 1.0 }.freeze

  draw do
    # Panel background
    rect(transform.x - 4.0, transform.y - 4.0, 260.0, 32.0, **PANEL_BG)
    rect(transform.x - 4.0, transform.y - 4.0, 260.0, 1.0, **PANEL_BORDER)

    text("Score: #{score}", transform.x, transform.y,
         size: 20.0, **SCORE_COLOR)
    text("Lives: #{lives}", transform.x + 160.0, transform.y,
         size: 20.0, **LIVES_COLOR)
  end
end
