# Game over / victory screen with dramatic neon presentation.
class GameOverScene < Dama::Scene
  compose do
    camera viewport_width: 800, viewport_height: 600
  end

  enter do
    @elapsed = 0.0
  end

  update do |dt, input|
    @elapsed += dt

    # Restart on space or click.
    switch_to(BreakoutScene) if input.key_just_pressed?(:space) || input.mouse_just_pressed?(:left)
  end

  # Draw directly since this scene has no nodes.
  def perform_draw(backend:)
    ctx = Dama::Node::DrawContext.new(node: nil, backend:, camera:)

    # Deep dark background
    ctx.rect(0, 0, 800, 600, r: 0.02, g: 0.02, b: 0.06, a: 1.0)

    # Dramatic glow behind text
    pulse = Math.sin((@elapsed || 0) * 2.0) * 0.2 + 0.8
    glow_alpha = pulse * 0.08
    ctx.circle(400, 260, 180, r: 1.0, g: 0.3, b: 0.1, a: glow_alpha)
    ctx.circle(400, 260, 120, r: 1.0, g: 0.4, b: 0.15, a: glow_alpha * 1.5)

    # Decorative horizontal lines
    ctx.rect(200, 210, 400, 1, r: 1.0, g: 0.4, b: 0.2, a: 0.3)
    ctx.rect(200, 290, 400, 1, r: 1.0, g: 0.4, b: 0.2, a: 0.3)

    # Text shadow
    ctx.text("GAME OVER", 262, 242, size: 52.0,
             r: 0.0, g: 0.0, b: 0.0, a: 0.6)

    # Pulsing title
    ctx.text("GAME OVER", 260, 240, size: 52.0,
             r: 1.0, g: pulse * 0.4, b: pulse * 0.2, a: 1.0)

    ctx.text("Press SPACE to play again", 252, 330, size: 22.0,
             r: 0.5, g: 0.6, b: 0.8, a: 0.8)
  end
end
