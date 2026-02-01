RSpec.describe Dama::Backend::Base do
  subject(:base) { described_class.new }

  # Backend::Base is an abstract interface. Every method should raise
  # NotImplementedError to enforce implementation in subclasses.
  %i[
    initialize_engine shutdown poll_events begin_frame end_frame
    delta_time frame_count clear draw_triangle draw_rect draw_circle
    draw_text draw_sprite load_texture load_texture_file unload_texture
    screenshot key_pressed? key_just_pressed? key_just_released?
    mouse_x mouse_y mouse_button_pressed?
    load_font
    load_sound play_sound stop_all_sounds unload_sound
    load_shader unload_shader set_shader
  ].each do |method_name|
    it "##{method_name} raises NotImplementedError" do
      # Pass dummy keyword args matching each method's signature.
      expect { base.public_send(method_name, **dummy_args_for(method_name)) }
        .to raise_error(NotImplementedError)
    end
  end

  DUMMY_ARGS = {
    initialize_engine: { configuration: nil },
    clear: { r: 0, g: 0, b: 0, a: 0 },
    draw_triangle: { x1: 0, y1: 0, x2: 0, y2: 0, x3: 0, y3: 0, r: 0, g: 0, b: 0, a: 0 },
    draw_rect: { x: 0, y: 0, w: 0, h: 0, r: 0, g: 0, b: 0, a: 0 },
    draw_circle: { cx: 0, cy: 0, radius: 0, r: 0, g: 0, b: 0, a: 0 },
    draw_text: { text: "", x: 0, y: 0, size: 16, r: 1, g: 1, b: 1, a: 1, font: nil },
    load_font: { path: "" },
    draw_sprite: { texture_handle: 0, x: 0, y: 0, w: 0, h: 0, r: 1, g: 1, b: 1, a: 1 },
    load_texture: { bytes: "" },
    load_texture_file: { path: "" },
    unload_texture: { handle: 0 },
    screenshot: { output_path: "" },
    key_pressed?: { key_code: 0 },
    key_just_pressed?: { key_code: 0 },
    key_just_released?: { key_code: 0 },
    mouse_button_pressed?: { button: 0 },
    load_sound: { path: "" },
    play_sound: { handle: 0 },
    unload_sound: { handle: 0 },
    load_shader: { source: "" },
    unload_shader: { handle: 0 },
    set_shader: { handle: 0 },
  }.freeze

  private

  def dummy_args_for(method_name)
    DUMMY_ARGS.fetch(method_name, {})
  end
end
