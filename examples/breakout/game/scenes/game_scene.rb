# Main breakout gameplay scene.
# Demonstrates: AABB physics, collision events, camera shake, dynamic node removal.
class BreakoutScene < Dama::Scene
  BRICK_ROWS = 7
  BRICK_COLS = 10
  BRICK_START_X = 30.0
  BRICK_START_Y = 60.0
  BRICK_SPACING_X = 74.0
  BRICK_SPACING_Y = 28.0

  ROW_COLORS = [
    { color_r: 1.0, color_g: 0.15, color_b: 0.3 },  # Hot pink
    { color_r: 1.0, color_g: 0.2, color_b: 0.2 },   # Red
    { color_r: 1.0, color_g: 0.6, color_b: 0.1 },   # Orange
    { color_r: 1.0, color_g: 1.0, color_b: 0.2 },   # Yellow
    { color_r: 0.2, color_g: 0.9, color_b: 0.2 },   # Green
    { color_r: 0.3, color_g: 0.5, color_b: 1.0 },   # Blue
    { color_r: 0.6, color_g: 0.3, color_b: 1.0 },   # Purple
  ].freeze

  # Checkerboard brightness: alternating columns are clearly darker
  COLUMN_BRIGHTNESS = { 0 => 1.0, 1 => 0.75 }.freeze

  compose do
    camera viewport_width: 800, viewport_height: 600
    physics gravity: [0.0, 0.0]

    # Background with grid and starfield.
    add Background, as: :background

    # Walls (invisible boundaries).
    add Wall, as: :top_wall, x: 0.0, y: -20.0
    add Wall, as: :bottom_wall, x: 0.0, y: 600.0
    add SideWall, as: :left_wall, x: -20.0, y: 0.0
    add SideWall, as: :right_wall, x: 800.0, y: 0.0

    # Paddle.
    add Paddle, as: :paddle

    # Ball.
    add Ball, as: :ball

    # Score HUD.
    group :ui do
      add ScoreLabel, as: :hud
    end

    # Bricks — slight brightness variation per column for a staggered gem look.
    BRICK_ROWS.times do |row|
      BRICK_COLS.times do |col|
        name = :"brick_#{row}_#{col}"
        x = BRICK_START_X + (col * BRICK_SPACING_X)
        y = BRICK_START_Y + (row * BRICK_SPACING_Y)
        base = ROW_COLORS[row]

        # Alternate columns get slightly darker/lighter for visual variety
        brightness = COLUMN_BRIGHTNESS.fetch((row + col) % 2)
        colors = {
          color_r: (base.fetch(:color_r) * brightness).clamp(0.0, 1.0),
          color_g: (base.fetch(:color_g) * brightness).clamp(0.0, 1.0),
          color_b: (base.fetch(:color_b) * brightness).clamp(0.0, 1.0)
        }

        add Brick, as: name, x:, y:, **colors
      end
    end
  end

  enter do
    @score = 0
    @lives = 3
    @bricks_remaining = BRICK_ROWS * BRICK_COLS
    @shake_timer = 0.0
    @game_over = false
    @elapsed = 0.0

    launch_ball
  end

  update do |dt, input|
    @elapsed += dt

    # Paddle movement.
    move_paddle(dt, input)

    # Ball trail.
    update_trail(dt)

    # Camera shake decay.
    update_shake(dt)

    # Check if ball fell below paddle.
    check_ball_lost

    # Check collisions (physics step runs after this).
    check_brick_collisions
    check_paddle_collision

    # Maintain constant ball speed (prevent drift from physics bouncing).
    normalize_ball_speed
  end

  private

  def move_paddle(dt, input)
    speed = Paddle::SPEED
    paddle.transform.x -= speed * dt if input.left?
    paddle.transform.x += speed * dt if input.right?

    # Clamp paddle to screen bounds.
    paddle.transform.x = paddle.transform.x.clamp(0.0, 800.0 - Paddle::PADDLE_WIDTH)

    # Mouse control: center paddle on mouse x.
    paddle.transform.x = (input.mouse_x - (Paddle::PADDLE_WIDTH / 2.0)).clamp(0.0, 800.0 - Paddle::PADDLE_WIDTH)
  end

  def launch_ball
    ball.transform.x = 400.0
    ball.transform.y = 530.0

    # Random angle between -45 and -135 degrees (upward).
    angle = (-0.75 + (rand * 0.5)) * Math::PI
    ball.physics.velocity_x = Ball::INITIAL_SPEED * Math.cos(angle)
    ball.physics.velocity_y = Ball::INITIAL_SPEED * Math.sin(angle)
    ball.trail_positions = []
  end

  def update_trail(dt)
    trail = ball.trail_positions || []
    trail.unshift([ball.transform.x, ball.transform.y])
    trail.pop while trail.length > Ball::TRAIL_LENGTH
    ball.trail_positions = trail
  end

  # Brick glow animation is now handled by the GPU shader (brick_glow.wgsl)
  # using the engine's time uniform — no per-frame Ruby update needed.

  def update_shake(dt)
    @shake_timer = [@shake_timer - dt, 0.0].max
    intensity = @shake_timer * 8.0
    camera.move_to(
      x: (rand - 0.5) * intensity,
      y: (rand - 0.5) * intensity,
    )
  end

  def trigger_shake
    @shake_timer = 0.15
  end

  def check_ball_lost
    return unless ball.transform.y > 590.0

    @lives -= 1
    hud.score = @score
    hud.lives = @lives

    return switch_to(GameOverScene) if @lives <= 0

    launch_ball
  end

  def check_brick_collisions
    # Only destroy one brick per frame to prevent multi-bounce glitches.
    BRICK_ROWS.times do |row|
      BRICK_COLS.times do |col|
        name = :"brick_#{row}_#{col}"
        brick_node = named_nodes[name]
        next unless brick_node
        next unless ball_hits_brick?(brick_node.node)

        destroy_brick(name, brick_node.node)
        return # One brick per frame.
      end
    end
  end

  def ball_hits_brick?(brick)
    bx = ball.transform.x
    by = ball.transform.y
    r = Ball::RADIUS + 2.0

    # Circle vs AABB.
    closest_x = bx.clamp(brick.transform.x, brick.transform.x + Brick::WIDTH)
    closest_y = by.clamp(brick.transform.y, brick.transform.y + Brick::HEIGHT)
    dx = bx - closest_x
    dy = by - closest_y
    (dx * dx) + (dy * dy) < r * r
  end

  def destroy_brick(name, brick)
    # Determine bounce direction before removing the brick.
    # Compare ball center to brick center to decide which axis to reflect.
    bx = ball.transform.x
    by = ball.transform.y
    brick_cx = brick.transform.x + (Brick::WIDTH / 2.0)
    brick_cy = brick.transform.y + (Brick::HEIGHT / 2.0)

    dx = (bx - brick_cx).abs / (Brick::WIDTH / 2.0)
    dy = (by - brick_cy).abs / (Brick::HEIGHT / 2.0)

    # Reflect on the axis with the greater relative distance
    # (that's the side the ball is approaching from).
    if dy > dx
      ball.physics.velocity_y = -ball.physics.velocity_y
    else
      ball.physics.velocity_x = -ball.physics.velocity_x
    end

    remove(name)
    @bricks_remaining -= 1
    @score += 10
    hud.score = @score

    normalize_ball_speed
    trigger_shake

    # Push ball out of the brick zone to prevent drilling.
    ball.transform.y += (ball.physics.velocity_y > 0 ? 3.0 : -3.0)

    return unless @bricks_remaining <= 0

    switch_to(GameOverScene)
  end

  def check_paddle_collision
    bx = ball.transform.x
    by = ball.transform.y + Ball::RADIUS
    px = paddle.transform.x
    py = paddle.transform.y

    return unless by >= py && by <= py + Paddle::PADDLE_HEIGHT &&
                  bx >= px && bx <= px + Paddle::PADDLE_WIDTH

    # Angle based on where ball hit the paddle (center = straight up, edges = angled).
    hit_pos = (bx - px) / Paddle::PADDLE_WIDTH # 0.0 to 1.0
    angle = (-0.25 - (hit_pos - 0.5) * 0.5) * Math::PI # -135° to -45°, centered at -90°

    ball.physics.velocity_x = Ball::INITIAL_SPEED * Math.cos(angle)
    ball.physics.velocity_y = Ball::INITIAL_SPEED * Math.sin(angle)
  end

  # Ensure ball always moves at constant speed regardless of bounce math.
  def normalize_ball_speed
    vx = ball.physics.velocity_x
    vy = ball.physics.velocity_y
    current_speed = Math.sqrt((vx * vx) + (vy * vy))
    return if current_speed < 0.001

    factor = Ball::INITIAL_SPEED / current_speed
    ball.physics.velocity_x = vx * factor
    ball.physics.velocity_y = vy * factor
  end
end
