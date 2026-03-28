RSpec.describe Dama::Backend::Web do
  subject(:backend) { described_class.new }

  include_context "with JS mock"

  describe "#initialize_engine" do
    it "does not raise" do
      config = Dama::Configuration.new(width: 800, height: 600, title: "Test")
      expect { backend.initialize_engine(configuration: config) }.not_to raise_error
    end
  end

  describe "#poll_events" do
    it "returns false (no quit in browser)" do
      expect(backend.poll_events).to be(false)
    end
  end

  describe "#begin_frame / #end_frame" do
    it "calls JS renderer and increments frame count" do
      backend.begin_frame
      backend.end_frame
      expect(backend.frame_count).to eq(1)
    end
  end

  describe "#clear" do
    it "calls dama_clear on JS renderer" do
      backend.begin_frame
      backend.clear(r: 1.0, g: 0.0, b: 0.0, a: 1.0)
      backend.end_frame

      calls = JS.global[:damaWgpu].calls
      clear_call = calls.find { |c| c.first == :dama_clear }
      expect(clear_call).to eq([:dama_clear, 1.0, 0.0, 0.0, 1.0])
    end
  end

  describe "#draw_triangle" do
    it "queues a triangle command (11 floats) in the command buffer" do
      backend.begin_frame
      backend.draw_triangle(x1: 0, y1: 0, x2: 10, y2: 0, x3: 5, y3: 10,
                            r: 1.0, g: 0.0, b: 0.0, a: 1.0)

      buf = backend.send(:command_buffer)
      expect(buf.float_count).to eq(11)
    end
  end

  describe "#draw_rect" do
    it "queues a rect command (9 floats) in the command buffer" do
      backend.begin_frame
      backend.draw_rect(x: 0, y: 0, w: 10, h: 10, r: 0.0, g: 1.0, b: 0.0, a: 1.0)

      buf = backend.send(:command_buffer)
      expect(buf.float_count).to eq(9)
    end
  end

  describe "#draw_circle" do
    it "queues a circle command (9 floats) regardless of segment count" do
      backend.begin_frame
      backend.draw_circle(cx: 5, cy: 5, radius: 3, r: 0.0, g: 0.0, b: 1.0, a: 1.0, segments: 32)

      buf = backend.send(:command_buffer)
      expect(buf.float_count).to eq(9)
    end
  end

  describe "#draw_text" do
    it "flushes commands then calls dama_render_text" do
      backend.begin_frame
      backend.draw_rect(x: 0, y: 0, w: 10, h: 10, r: 1.0, g: 1.0, b: 1.0, a: 1.0)
      backend.draw_text(text: "Hello", x: 10, y: 10, size: 20, r: 1.0, g: 1.0, b: 0.0, a: 1.0)
      backend.end_frame

      calls = JS.global[:damaWgpu].calls
      text_call = calls.find { |c| c.first == :dama_render_text }
      expect(text_call).to eq([:dama_render_text, "Hello", 10, 10, 20, 1.0, 1.0, 0.0, 1.0])
    end
  end

  describe "#draw_sprite" do
    it "queues a sprite command (14 floats) in one batch" do
      backend.begin_frame
      backend.draw_sprite(texture_handle: 42, x: 0, y: 0, w: 32, h: 32)

      buf = backend.send(:command_buffer)
      expect(buf.float_count).to eq(14)
    end
  end

  describe "#delta_time" do
    it "reads from JS damaTime" do
      expect(backend.delta_time).to be_a(Float)
    end
  end

  describe "input methods" do
    it "#key_pressed? returns false" do
      expect(backend.key_pressed?(key_code: 80)).to be(false)
    end

    it "#key_just_pressed? returns false" do
      expect(backend.key_just_pressed?(key_code: 80)).to be(false)
    end

    it "#key_just_released? returns false" do
      expect(backend.key_just_released?(key_code: 80)).to be(false)
    end

    it "#mouse_x / #mouse_y return floats" do
      expect(backend.mouse_x).to be_a(Float)
      expect(backend.mouse_y).to be_a(Float)
    end

    it "#mouse_button_pressed? returns false" do
      expect(backend.mouse_button_pressed?(button: 0)).to be(false)
    end
  end

  describe "#screenshot" do
    it "is a no-op" do
      expect { backend.screenshot(output_path: "/tmp/test.png") }.not_to raise_error
    end
  end

  describe "#load_texture / #unload_texture" do
    it "loads texture from bytes" do
      expect(backend.load_texture(bytes: "fake png data")).to eq(0)
    end

    it "loads texture from file" do
      Dir.mktmpdir do |dir|
        path = File.join(dir, "test.png")
        File.binwrite(path, "fake png data")
        expect(backend.load_texture_file(path:)).to eq(0)
      end
    end

    it "unloads without error" do
      expect { backend.unload_texture(handle: 0) }.not_to raise_error
    end
  end

  describe "#load_sound" do
    it "loads a sound from a valid file" do
      Dir.mktmpdir do |dir|
        path = File.join(dir, "beep.wav")
        File.binwrite(path, "RIFF fake wav data")
        handle = backend.load_sound(path:)
        expect(handle).to be_a(Integer)
        expect(handle).to be > 0
      end
    end

    it "raises when file does not exist" do
      expect { backend.load_sound(path: "/nonexistent/beep.wav") }.to raise_error(Errno::ENOENT)
    end
  end

  describe "#play_sound" do
    it "does not raise for any handle" do
      expect { backend.play_sound(handle: 1, volume: 0.5) }.not_to raise_error
    end

    it "supports looping" do
      expect { backend.play_sound(handle: 1, volume: 1.0, loop: true) }.not_to raise_error
    end
  end

  describe "#stop_all_sounds" do
    it "does not raise" do
      expect { backend.stop_all_sounds }.not_to raise_error
    end
  end

  describe "#unload_sound" do
    it "does not raise" do
      expect { backend.unload_sound(handle: 1) }.not_to raise_error
    end
  end

  describe "#load_shader / #unload_shader / #set_shader" do
    it "loads a shader and returns a handle" do
      handle = backend.load_shader(source: "fake wgsl")
      expect(handle).to eq(0) # JS mock returns JsValue(nil).to_i = 0
    end

    it "unloads without error" do
      expect { backend.unload_shader(handle: 1) }.not_to raise_error
    end

    it "queues set_shader as a command" do
      backend.set_shader(handle: 42)

      # The command should be in the command buffer (flushed on end_frame).
      # Verify by checking the buffer has the set_shader tag.
      buf = backend.send(:command_buffer)
      data = buf.to_a
      expect(data).to include(5.0, 42.0)
    end
  end
end
