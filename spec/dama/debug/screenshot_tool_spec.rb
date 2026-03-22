RSpec.describe Dama::Debug::ScreenshotTool do
  subject(:tool) { described_class.new(backend:) }

  include_context "with headless backend"

  describe "#capture" do
    it "creates a PNG file at the given path" do
      backend.clear(r: 0.0, g: 0.0, b: 1.0, a: 1.0)

      Dir.mktmpdir do |dir|
        path = File.join(dir, "screenshot.png")
        tool.capture(output_path: path)

        expect(File.exist?(path)).to be(true)
        expect(File.size(path)).to be > 0
      end
    end
  end
end
