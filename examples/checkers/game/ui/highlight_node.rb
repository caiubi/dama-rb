# Semi-transparent circle overlay showing a valid move destination.
class HighlightNode < Dama::Node
  component Transform, as: :transform
  attribute :highlight_radius, default: 25.0
  attribute :highlight_type, default: :valid_move

  COLORS = {
    valid_move: Dama::Colors::GREEN.with_alpha(a: 0.4),
    capture: Dama::Colors::RED.with_alpha(a: 0.4)
  }.freeze

  draw do
    color = COLORS.fetch(highlight_type)
    circle(transform.x, transform.y, highlight_radius, color:)
  end
end
