# Pulsing glow ring drawn behind a selected piece.
# Uses sine wave to animate the radius for a breathing effect.
class SelectionNode < Dama::Node
  component Transform, as: :transform
  attribute :glow_radius, default: 34.0
  attribute :pulse_time, default: 0.0

  GLOW_COLOR = Dama::Colors::YELLOW.with_alpha(a: 0.5)
  PULSE_SPEED = 4.0
  PULSE_AMPLITUDE = 4.0

  draw do
    # Sine-based pulse creates a breathing glow effect.
    pulse = Math.sin(pulse_time * PULSE_SPEED) * PULSE_AMPLITUDE
    circle(transform.x, transform.y, glow_radius + pulse, color: GLOW_COLOR)
  end
end
