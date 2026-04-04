# Dark overlay behind the game over text.
class GameOverBackgroundNode < Dama::Node
  BG = Dama::Colors::Color.new(r: 0.04, g: 0.04, b: 0.06, a: 0.92)

  draw do
    rect(0, 0, 800, 600, color: BG)
  end
end

# Decorative piece circle for the winner.
class GameOverPieceNode < Dama::Node
  attribute :winner_team, default: :red

  TEAM_COLORS = {
    red: { outer: Dama::Colors::DARK_RED, inner: Dama::Colors::RED },
    dark: { outer: Dama::Colors::SLATE, inner: Dama::Colors::CHARCOAL }
  }.freeze

  HIGHLIGHT = Dama::Colors::Color.new(r: 1.0, g: 1.0, b: 1.0, a: 0.25)

  draw do
    colors = TEAM_COLORS.fetch(winner_team)
    circle(400.0, 200.0, 50.0, color: colors.fetch(:outer))
    circle(400.0, 200.0, 44.0, color: colors.fetch(:inner))
    circle(391.0, 190.0, 15.0, color: HIGHLIGHT)
  end
end

class GameOverTextNode < Dama::Node
  attribute :winner_text, default: "Game Over"

  draw do
    # Shadow
    text(winner_text, 202.0, 282.0, size: 52.0, r: 0.0, g: 0.0, b: 0.0, a: 0.5)
    # Main text
    text(winner_text, 200.0, 280.0, size: 52.0, color: Dama::Colors::GOLD)

    # Divider
    rect(300.0, 350.0, 200.0, 2.0, color: Dama::Colors::DARK_BROWN)

    text("Click to play again", 268.0, 375.0, size: 22.0, color: Dama::Colors::LIGHT_TAN)
  end
end

class GameOverScene < Dama::Scene
  compose do
    add GameOverBackgroundNode, as: :overlay
    add GameOverPieceNode, as: :winner_piece
    add GameOverTextNode, as: :game_over_text
  end

  update do |_dt, input|
    switch_to(TitleScene) if input.mouse_clicked?
  end
end
