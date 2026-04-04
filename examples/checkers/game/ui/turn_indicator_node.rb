# Sidebar status panel showing turn indicator and piece counts.
class TurnIndicatorNode < Dama::Node
  attribute :label, default: "Red's Turn"
  attribute :red_count, default: 12
  attribute :dark_count, default: 12

  PANEL_X = 642.0
  PANEL_Y = 20.0
  PANEL_W = 148.0
  PANEL_H = 220.0

  PANEL_BG = Dama::Colors::Color.new(r: 0.08, g: 0.09, b: 0.10, a: 0.90)
  PANEL_FRAME = Dama::Colors::Color.new(r: 0.30, g: 0.16, b: 0.07, a: 1.0)
  PANEL_FRAME_INNER = Dama::Colors::Color.new(r: 0.52, g: 0.33, b: 0.18, a: 1.0)
  DIVIDER_COLOR = Dama::Colors::Color.new(r: 0.44, g: 0.26, b: 0.13, a: 0.5)
  COUNT_TEXT = Dama::Colors::CREAM

  TEAM_VISUALS = {
    red: {
      text_color: Dama::Colors::RED,
      outer: Dama::Colors::DARK_RED,
      inner: Dama::Colors::RED
    },
    dark: {
      text_color: Dama::Colors::LIGHT_GRAY,
      outer: Dama::Colors::SLATE,
      inner: Dama::Colors::CHARCOAL
    }
  }.freeze

  HIGHLIGHT = Dama::Colors::Color.new(r: 1.0, g: 1.0, b: 1.0, a: 0.25)

  TEAM_BY_PREFIX = {
    "R" => :red,
    "D" => :dark
  }.freeze

  # Draws a mini piece at the given center with a specular highlight.
  DRAW_PIECE = lambda { |ctx, cx, cy, radius, visuals|
    ctx.circle(cx, cy, radius, color: visuals.fetch(:outer))
    ctx.circle(cx, cy, radius - 4.0, color: visuals.fetch(:inner))
    ctx.circle(cx - (radius * 0.2), cy - (radius * 0.25), radius * 0.3, color: HIGHLIGHT)
  }

  draw do
    team = TEAM_BY_PREFIX.fetch(label[0], :red)
    visuals = TEAM_VISUALS.fetch(team)

    # Panel frame (matching board frame style)
    rect(PANEL_X - 4.0, PANEL_Y - 4.0, PANEL_W + 8.0, PANEL_H + 8.0, color: PANEL_FRAME)
    rect(PANEL_X - 2.0, PANEL_Y - 2.0, PANEL_W + 4.0, PANEL_H + 4.0, color: PANEL_FRAME_INNER)
    rect(PANEL_X, PANEL_Y, PANEL_W, PANEL_H, color: PANEL_BG)

    # --- Turn indicator ---
    text(label, PANEL_X + 15.0, PANEL_Y + 12.0, size: 20.0, color: visuals.fetch(:text_color))
    DRAW_PIECE.call(self, PANEL_X + (PANEL_W / 2.0), PANEL_Y + 55.0, 16.0, visuals)

    # --- Divider ---
    rect(PANEL_X + 15.0, PANEL_Y + 80.0, PANEL_W - 30.0, 1.0, color: DIVIDER_COLOR)

    # --- Red piece count ---
    red_vis = TEAM_VISUALS.fetch(:red)
    DRAW_PIECE.call(self, PANEL_X + 28.0, PANEL_Y + 109.0, 14.0, red_vis)
    text(red_count.to_s, PANEL_X + 55.0, PANEL_Y + 97.0, size: 28.0, color: COUNT_TEXT)

    # --- Dark piece count ---
    dark_vis = TEAM_VISUALS.fetch(:dark)
    DRAW_PIECE.call(self, PANEL_X + 28.0, PANEL_Y + 164.0, 14.0, dark_vis)
    text(dark_count.to_s, PANEL_X + 55.0, PANEL_Y + 152.0, size: 28.0, color: COUNT_TEXT)
  end
end
