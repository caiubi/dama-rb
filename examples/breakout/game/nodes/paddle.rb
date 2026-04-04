# The player-controlled paddle at the bottom of the screen.
class Paddle < Dama::Node
  PADDLE_WIDTH = 120.0
  PADDLE_HEIGHT = 16.0
  SPEED = 500.0

  component Transform, as: :transform, x: 340.0, y: 550.0
  physics_body type: :kinematic, collider: :rect,
               width: PADDLE_WIDTH, height: PADDLE_HEIGHT

  draw do
    center_x = transform.x + (PADDLE_WIDTH / 2.0)

    # Glow underneath the paddle
    circle(center_x, transform.y + PADDLE_HEIGHT + 4.0, 60.0,
           r: 0.2, g: 0.5, b: 1.0, a: 0.08)
    circle(center_x, transform.y + PADDLE_HEIGHT + 2.0, 30.0,
           r: 0.3, g: 0.6, b: 1.0, a: 0.12)

    # Paddle body
    rect(transform.x, transform.y, PADDLE_WIDTH, PADDLE_HEIGHT,
         r: 0.2, g: 0.6, b: 1.0, a: 1.0)

    # Top highlight stripe
    rect(transform.x + 4.0, transform.y + 2.0, PADDLE_WIDTH - 8.0, 4.0,
         r: 0.5, g: 0.85, b: 1.0, a: 0.7)

    # Bottom shadow edge
    rect(transform.x, transform.y + PADDLE_HEIGHT - 2.0, PADDLE_WIDTH, 2.0,
         r: 0.1, g: 0.3, b: 0.6, a: 0.5)

    # End caps (bright dots on edges)
    circle(transform.x + 4.0, transform.y + (PADDLE_HEIGHT / 2.0), 3.0,
           r: 0.6, g: 0.9, b: 1.0, a: 0.5)
    circle(transform.x + PADDLE_WIDTH - 4.0, transform.y + (PADDLE_HEIGHT / 2.0), 3.0,
           r: 0.6, g: 0.9, b: 1.0, a: 0.5)
  end
end
