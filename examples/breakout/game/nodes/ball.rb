# The bouncing ball. Uses a custom GPU shader for color-cycling effect.
class Ball < Dama::Node
  RADIUS = 8.0
  INITIAL_SPEED = 350.0
  TRAIL_LENGTH = 8

  component Transform, as: :transform, x: 400.0, y: 530.0
  physics_body type: :dynamic, collider: :circle, radius: RADIUS, restitution: 1.0
  shader :trail, path: File.join(__dir__, "../../assets/shaders/ball_trail.wgsl")

  attribute :trail_positions, default: nil

  draw do
    # Outer glow halo
    circle(transform.x, transform.y, RADIUS * 3.0,
           r: 1.0, g: 0.4, b: 0.1, a: 0.06)
    circle(transform.x, transform.y, RADIUS * 2.0,
           r: 1.0, g: 0.5, b: 0.15, a: 0.10)

    # Draw trail (fading ghost circles) with shader color cycling.
    (trail_positions || []).each_with_index do |pos, i|
      trail_size = TRAIL_LENGTH.to_f
      alpha = (i + 1).to_f / trail_size * 0.35
      scale = 1.0 - ((trail_size - i - 1) / trail_size * 0.4)
      circle(pos[0], pos[1], RADIUS * scale,
             r: 1.0, g: 0.4, b: 0.2, a: alpha,
             shader: trail)
    end

    # Main ball with shader color cycling.
    circle(transform.x, transform.y, RADIUS,
           r: 1.0, g: 0.5, b: 0.1, a: 1.0,
           shader: trail)

    # Specular highlight
    circle(transform.x - 2.5, transform.y - 2.5, RADIUS * 0.4,
           r: 1.0, g: 0.95, b: 0.8, a: 0.9)
  end
end
