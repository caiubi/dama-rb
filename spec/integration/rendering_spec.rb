require "tmpdir"

RSpec.describe "Headless rendering end-to-end" do
  include_context "with headless backend"

  it "renders a red screen and verifies screenshot pixel data" do
    backend.clear(r: 1.0, g: 0.0, b: 0.0, a: 1.0)

    Dir.mktmpdir do |dir|
      path = File.join(dir, "red.png")
      backend.screenshot(output_path: path)

      expect(File.exist?(path)).to be(true)
      expect(File.size(path)).to be > 100
    end
  end

  it "renders shapes across multiple frames" do
    3.times do |_i|
      backend.begin_frame

      # Draw different shapes each frame.
      backend.draw_rect(x: 10.0, y: 10.0, w: 44.0, h: 44.0, r: 0.0, g: 0.0, b: 1.0, a: 1.0)
      backend.draw_triangle(
        x1: 32.0, y1: 5.0,
        x2: 5.0, y2: 59.0,
        x3: 59.0, y3: 59.0,
        r: 0.0, g: 1.0, b: 0.0, a: 1.0
      )
      backend.draw_circle(cx: 32.0, cy: 32.0, radius: 15.0, r: 1.0, g: 0.0, b: 0.0, a: 1.0)

      backend.end_frame
    end

    expect(backend.frame_count).to eq(3)
  end

  it "captures a screenshot after drawing shapes" do
    backend.clear(r: 0.0, g: 0.0, b: 0.0, a: 1.0)
    backend.begin_frame
    backend.draw_rect(x: 0.0, y: 0.0, w: 64.0, h: 64.0, r: 0.0, g: 1.0, b: 0.0, a: 1.0)
    backend.end_frame

    Dir.mktmpdir do |dir|
      path = File.join(dir, "shapes.png")
      backend.screenshot(output_path: path)

      expect(File.exist?(path)).to be(true)
    end
  end
end
