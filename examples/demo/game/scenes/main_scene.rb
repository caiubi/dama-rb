class MainScene < Dama::Scene
  compose do
    add Player, as: :player
    add Smiley, as: :smiley
    add Landmark, as: :green_dot, cx: 100.0, cy: 100.0, radius: 30.0,
                  color_r: 0.2, color_g: 0.8, color_b: 0.3
    add Landmark, as: :blue_dot, cx: 200.0, cy: 450.0, radius: 25.0,
                  color_r: 0.2, color_g: 0.3, color_b: 0.9
    add FpsOverlay, as: :fps_display
  end

  update do |dt, input|
    player.transform.x -= player.transform.speed * dt if input.left?
    player.transform.x += player.transform.speed * dt if input.right?
    player.transform.y -= player.transform.speed * dt if input.up?
    player.transform.y += player.transform.speed * dt if input.down?

    smiley.transform.x -= smiley.transform.speed * dt if input.left?
    smiley.transform.x += smiley.transform.speed * dt if input.right?

    fps_display.fps = dt > 0 ? (1.0 / dt) : 0.0
  end
end
