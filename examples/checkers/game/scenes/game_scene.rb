# The main gameplay scene. Demonstrates all Phase 2 engine features:
# - Easing (smooth piece movement via ease_out_quad)
# - Camera (zoom with +/- keys)
# - Audio (SFX declared via `sound` DSL, played via `play`)
# - EventBus (GameState emits events, scene listens)
class GameScene < Dama::Scene
  BOARD_ORIGIN_X = 60.0
  BOARD_ORIGIN_Y = 20.0
  SQUARE_SIZE = 70.0

  sound :select,  path: File.join(__dir__, "../../assets/sfx/select.wav")
  sound :move,    path: File.join(__dir__, "../../assets/sfx/move.wav")
  sound :capture, path: File.join(__dir__, "../../assets/sfx/capture.wav")
  sound :king,    path: File.join(__dir__, "../../assets/sfx/king.wav")
  sound :gameover, path: File.join(__dir__, "../../assets/sfx/gameover.wav")

  compose do
    camera viewport_width: 800, viewport_height: 600

    group :background_layer do
      add BackgroundNode, as: :background
    end
    group :board_layer do
      add BoardNode, as: :board, origin_x: BOARD_ORIGIN_X, origin_y: BOARD_ORIGIN_Y,
                     square_size: SQUARE_SIZE
    end
    group :highlight_layer do; end
    group :piece_layer do; end
    group :ui_layer do
      add TurnIndicatorNode, as: :turn_text
    end
  end

  enter do
    converter = CoordinateConverter.new(
      origin_x: BOARD_ORIGIN_X,
      origin_y: BOARD_ORIGIN_Y,
      square_size: SQUARE_SIZE
    )
    @game_state = GameState.new(scene: self, converter:)
    wire_events(@game_state.events)
    @game_state.setup_pieces
  end

  update do |dt, input|
    @game_state.handle(delta_time: dt, input:)

    # Camera: zoom with +/- keys.
    camera.zoom_to(level: camera.zoom + 0.02) if input.key_pressed?(:equal)
    camera.zoom_to(level: camera.zoom - 0.02) if input.key_pressed?(:minus)

    switch_to(GameOverScene) if @game_state.winner
  end

  private

  def wire_events(bus)
    bus.on(:piece_selected) { play(:select) }
    bus.on(:piece_moved) { play(:move) }
    bus.on(:piece_captured) { play(:capture) }
    bus.on(:king_promoted) { play(:king) }
    bus.on(:game_over) { play(:gameover) }
  end
end
