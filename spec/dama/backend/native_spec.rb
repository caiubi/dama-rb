RSpec.describe Dama::Backend::Native do
  include_context "with headless backend"

  describe "#initialize_engine / #shutdown" do
    it "initializes in headless mode without error" do
      # The shared context already initializes — if we got here, it worked.
      expect(backend.frame_count).to eq(0)
    end
  end

  describe "#begin_frame / #end_frame" do
    it "completes a frame cycle and increments frame count" do
      backend.begin_frame
      backend.end_frame

      expect(backend.frame_count).to eq(1)
    end
  end

  describe "#delta_time" do
    it "returns a non-negative number after a frame" do
      backend.begin_frame
      backend.end_frame

      expect(backend.delta_time).to be >= 0.0
      expect(backend.delta_time).to be < 1.0
    end
  end

  describe "#poll_events" do
    it "returns false in headless mode (no quit requested)" do
      expect(backend.poll_events).to be(false)
    end
  end

  describe "#clear" do
    it "clears the render target without error" do
      expect { backend.clear(r: 1.0, g: 0.0, b: 0.0, a: 1.0) }.not_to raise_error
    end
  end

  describe "#draw_triangle" do
    it "draws a triangle without error" do
      backend.begin_frame
      expect do
        backend.draw_triangle(
          x1: 32.0, y1: 5.0,
          x2: 5.0, y2: 59.0,
          x3: 59.0, y3: 59.0,
          r: 0.0, g: 1.0, b: 0.0, a: 1.0
        )
      end.not_to raise_error
      backend.end_frame
    end
  end

  describe "#draw_text" do
    it "renders text without error" do
      backend.begin_frame
      expect do
        backend.draw_text(text: "Hello", x: 10.0, y: 10.0, size: 24.0, r: 1.0, g: 1.0, b: 1.0, a: 1.0)
      end.not_to raise_error
      backend.end_frame
    end
  end

  describe "#draw_rect" do
    it "draws a rectangle without error" do
      backend.begin_frame
      expect do
        backend.draw_rect(x: 10.0, y: 10.0, w: 44.0, h: 44.0, r: 0.0, g: 0.0, b: 1.0, a: 1.0)
      end.not_to raise_error
      backend.end_frame
    end
  end

  describe "#draw_circle" do
    it "draws a circle without error" do
      backend.begin_frame
      expect do
        backend.draw_circle(cx: 32.0, cy: 32.0, radius: 20.0, r: 1.0, g: 1.0, b: 1.0, a: 1.0, segments: 16)
      end.not_to raise_error
      backend.end_frame
    end
  end

  describe "#screenshot" do
    it "captures the render target to a PNG file" do
      backend.clear(r: 1.0, g: 0.0, b: 0.0, a: 1.0)

      Dir.mktmpdir do |dir|
        path = File.join(dir, "test_screenshot.png")
        backend.screenshot(output_path: path)

        expect(File.exist?(path)).to be(true)
        expect(File.size(path)).to be > 0
      end
    end
  end

  describe "#key_pressed?" do
    it "returns false in headless mode (no input)" do
      expect(backend.key_pressed?(key_code: 0)).to be(false)
    end
  end

  describe "#key_just_released?" do
    it "returns false in headless mode" do
      expect(backend.key_just_released?(key_code: 0)).to be(false)
    end
  end

  describe "#mouse_x / #mouse_y" do
    it "returns 0.0 in headless mode" do
      expect(backend.mouse_x).to eq(0.0)
      expect(backend.mouse_y).to eq(0.0)
    end
  end

  describe "#mouse_button_pressed?" do
    it "returns false in headless mode" do
      expect(backend.mouse_button_pressed?(button: 0)).to be(false)
    end
  end

  describe "#load_font" do
    it "loads a custom font file" do
      font_path = File.join(Dama.root, "ext", "dama_native", "src", "fonts", "NotoSans-Regular.ttf")
      expect { backend.load_font(path: font_path) }.not_to raise_error
    end
  end

  describe "#draw_text with font:" do
    it "renders text with a custom font family" do
      font_path = File.join(Dama.root, "ext", "dama_native", "src", "fonts", "NotoSans-Regular.ttf")
      backend.load_font(path: font_path)

      backend.begin_frame
      backend.clear(r: 0.0, g: 0.0, b: 0.0, a: 1.0)
      expect do
        backend.draw_text(text: "Custom", x: 10.0, y: 10.0, size: 24.0,
                          r: 1.0, g: 1.0, b: 1.0, a: 1.0, font: "Noto Sans")
      end.not_to raise_error
      backend.end_frame
    end
  end

  describe "#check_result (error path)" do
    it "raises when the engine returns an error" do
      backend.shutdown
      expect { backend.begin_frame }.to raise_error(RuntimeError, /Engine not initialized/)
    end
  end
end
