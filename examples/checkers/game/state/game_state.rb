# Manages checkers game state and dispatches input to the current handler.
# State transitions happen via hash lookup — no conditionals.
# Emits events via EventBus for decoupled audio/visual effects.
class GameState
  OPPONENT = { red: :dark, dark: :red }.freeze

  attr_reader :board, :current_team, :selected_position, :valid_moves,
              :tweens, :winner, :converter, :scene, :events

  def initialize(scene:, converter:, events: Dama::EventBus.new)
    @scene = scene
    @converter = converter
    @events = events
    @board = Board.new
    @current_team = :red
    @selected_position = nil
    @valid_moves = []
    @tweens = Dama::Tween::Manager.new
    @winner = nil
    @handlers = build_handlers
  end

  def handle(delta_time:, input:)
    tweens.update(delta_time:)
    update_selection_pulse(delta_time:)
    current_handler.handle(delta_time:, input:)
  end

  def select_piece(position:, moves:)
    @selected_position = position
    @valid_moves = moves
    show_selection(position:)
    show_highlights(moves:)
    transition_to(:piece_selected)
    events.emit(:piece_selected, position:)
  end

  def deselect
    clear_selection
    @selected_position = nil
    @valid_moves = []
    transition_to(:selecting)
  end

  def execute_move(move:)
    clear_selection

    executor = MoveExecutor.new(board:)
    @board = executor.execute(move:)

    # Animate the piece sliding to its new position.
    piece_name = piece_name_for(position: move.from)
    target_pixel = converter.to_pixel(position: move.to)

    piece_node = scene.send(piece_name)
    add_move_tween(piece_node:, target_pixel:) do
      finish_move(move:, piece_name:)
    end

    # Remove captured piece nodes.
    move.captures.each do |captured_pos|
      captured_name = find_piece_name_at(position: captured_pos)
      scene.remove(captured_name) if captured_name
      events.emit(:piece_captured, position: captured_pos)
    end

    events.emit(:piece_moved, from: move.from, to: move.to)
    transition_to(:animating)
  end

  def finish_animation
    transition_to(:selecting)
  end

  # Place all 24 starting pieces as nodes in the scene.
  def setup_pieces
    board.all_pieces.each do |position, piece|
      pixel = converter.to_pixel(position:)
      name = :"piece_#{position.row}_#{position.col}"

      scene.add(PieceNode, as: name, group: :piece_layer,
                x: pixel.fetch(:x), y: pixel.fetch(:y),
                team: piece.team, king: piece.king)
    end
  end

  private

  attr_reader :handlers

  def build_handlers
    {
      selecting: SelectingHandler.new(game_state: self),
      piece_selected: PieceSelectedHandler.new(game_state: self),
      animating: AnimatingHandler.new(game_state: self)
    }
  end

  def current_handler
    handlers.fetch(@current_state_key || :selecting)
  end

  def transition_to(state)
    @current_state_key = state
  end

  def finish_move(move:, piece_name:)
    new_name = :"piece_#{move.to.row}_#{move.to.col}"
    piece = board.piece_at(position: move.to)

    # Remove old node and re-add at new position name.
    pixel = converter.to_pixel(position: move.to)
    scene.remove(piece_name)
    scene.add(PieceNode, as: new_name, group: :piece_layer,
              x: pixel.fetch(:x), y: pixel.fetch(:y),
              team: piece.team, king: piece.king)

    events.emit(:king_promoted, position: move.to, team: piece.team) if piece.king

    # After a capture, check if the same piece can capture again (multi-jump).
    continued_captures = check_continued_captures(position: move.to)

    return continue_jump(position: move.to, moves: continued_captures) if move.capture? && continued_captures.any?

    # No more jumps — switch turns.
    end_turn
  end

  def check_continued_captures(position:)
    finder = MoveFinder.new(board:)
    finder.moves_for(position:).select(&:capture?)
  end

  def continue_jump(position:, moves:)
    @selected_position = position
    @valid_moves = moves
    show_selection(position:)
    show_highlights(moves:)
    transition_to(:piece_selected)
  end

  def end_turn
    next_team = OPPONENT.fetch(current_team)
    rules = Rules.new(board:)
    @winner = rules.winner(current_team: next_team)
    @current_team = next_team
    update_turn_indicator
    events.emit(:turn_changed, team: current_team)
    events.emit(:game_over, winner:) if winner
  end

  def show_selection(position:)
    pixel = converter.to_pixel(position:)
    scene.add(SelectionNode, as: :selection_glow, group: :highlight_layer,
              x: pixel.fetch(:x), y: pixel.fetch(:y))
  end

  def show_highlights(moves:)
    moves.each_with_index do |move, i|
      pixel = converter.to_pixel(position: move.to)
      highlight_type = move.capture? ? :capture : :valid_move
      scene.add(HighlightNode, as: :"highlight_#{i}", group: :highlight_layer,
                x: pixel.fetch(:x), y: pixel.fetch(:y),
                highlight_type:)
    end
  end

  def clear_selection
    scene.remove(:selection_glow) if scene.respond_to?(:selection_glow)

    valid_moves.each_index do |i|
      name = :"highlight_#{i}"
      scene.remove(name) if scene.respond_to?(name)
    end
  end

  def piece_name_for(position:)
    :"piece_#{position.row}_#{position.col}"
  end

  def find_piece_name_at(position:)
    name = piece_name_for(position:)
    scene.respond_to?(name) ? name : nil
  end

  def add_move_tween(piece_node:, target_pixel:, &on_complete)
    tweens.add(tween: Dama::Tween::Lerp.new(
      target: piece_node.transform, attribute: :x,
      from: piece_node.transform.x, to: target_pixel.fetch(:x),
      duration: 0.25, easing: :ease_out_quad
    ))
    tweens.add(tween: Dama::Tween::Lerp.new(
      target: piece_node.transform, attribute: :y,
      from: piece_node.transform.y, to: target_pixel.fetch(:y),
      duration: 0.25, easing: :ease_out_quad,
      on_complete:
    ))
  end

  def update_selection_pulse(delta_time:)
    return unless selected_position

    glow = scene.selection_glow
    glow.pulse_time = glow.pulse_time + delta_time
  rescue KeyError
    # Selection glow may not exist yet or was already removed.
    nil
  end

  TEAM_LABELS = { red: "Red's Turn", dark: "Dark's Turn" }.freeze

  def update_turn_indicator
    return unless scene.respond_to?(:turn_text)

    scene.turn_text.label = TEAM_LABELS.fetch(current_team)
    scene.turn_text.red_count = board.pieces_for(team: :red).size
    scene.turn_text.dark_count = board.pieces_for(team: :dark).size
  end
end
