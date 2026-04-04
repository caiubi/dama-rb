# Renders a single checker piece with depth: shadow, concentric rings,
# specular highlight, and a gold crown shape for kings.
class PieceNode < Dama::Node
  component Transform, as: :transform
  attribute :team, default: :red
  attribute :king, default: false
  attribute :piece_radius, default: 28.0

  TEAM_COLORS = {
    red: {
      outer: Dama::Colors::DARK_RED,
      inner: Dama::Colors::RED,
      rim: Dama::Colors::Color.new(r: 0.75, g: 0.12, b: 0.12, a: 1.0)
    },
    dark: {
      outer: Dama::Colors::SLATE,
      inner: Dama::Colors::CHARCOAL,
      rim: Dama::Colors::Color.new(r: 0.22, g: 0.25, b: 0.28, a: 1.0)
    }
  }.freeze

  SHADOW_COLOR = Dama::Colors::Color.new(r: 0.0, g: 0.0, b: 0.0, a: 0.3)
  HIGHLIGHT_COLOR = Dama::Colors::Color.new(r: 1.0, g: 1.0, b: 1.0, a: 0.3)
  SHEEN_COLOR = Dama::Colors::Color.new(r: 1.0, g: 1.0, b: 1.0, a: 0.10)

  # King crown drawing: true draws a gold crown shape, false is a no-op.
  CROWN_DRAW = {
    true => lambda { |ctx, x, y|
      # Crown base
      ctx.rect(x - 10.0, y - 2.0, 20.0, 8.0, color: Dama::Colors::GOLD)
      # Three crown points
      ctx.triangle(x - 12.0, y - 2.0, x - 6.0, y - 2.0, x - 9.0, y - 12.0, color: Dama::Colors::GOLD)
      ctx.triangle(x - 3.0, y - 2.0, x + 3.0, y - 2.0, x, y - 14.0, color: Dama::Colors::GOLD)
      ctx.triangle(x + 6.0, y - 2.0, x + 12.0, y - 2.0, x + 9.0, y - 12.0, color: Dama::Colors::GOLD)
    },
    false => ->(_ctx, _x, _y) {}
  }.freeze

  draw do
    colors = TEAM_COLORS.fetch(team)

    # Drop shadow (offset down-right)
    circle(transform.x + 2.0, transform.y + 3.0, piece_radius, color: SHADOW_COLOR)

    # Outer ring
    circle(transform.x, transform.y, piece_radius, color: colors.fetch(:outer))

    # Mid rim for depth
    circle(transform.x, transform.y, piece_radius - 3.0, color: colors.fetch(:rim))

    # Inner face
    circle(transform.x, transform.y, piece_radius - 6.0, color: colors.fetch(:inner))

    # Specular highlight (upper-left gloss)
    circle(transform.x - 7.0, transform.y - 8.0, 10.0, color: HIGHLIGHT_COLOR)

    # Subtle sheen across top half
    circle(transform.x, transform.y - 4.0, piece_radius - 8.0, color: SHEEN_COLOR)

    # Crown for kings
    CROWN_DRAW.fetch(king).call(self, transform.x, transform.y)
  end
end
