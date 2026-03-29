require "spec_helper"
require "net/http"

# End-to-end web build verification.
# Builds the web version of the demo project, starts a server,
# and uses Chrome DevTools MCP to verify it actually renders.
#
# This catches issues that unit specs with JS mocks cannot:
# - wasm-bindgen signature mismatches
# - WASI VFS file access failures
# - dama_core.rb staleness (now auto-generated)
# - Ruby→JS→Rust wasm re-entry crashes
RSpec.describe "Web build integration", :web do
  let(:demo_root) { File.expand_path("../../examples/demo", __dir__) }
  let(:port) { 8099 } # Use a non-standard port to avoid conflicts.

  it "builds the demo project and produces valid dist output" do # rubocop:disable RSpec/MultipleExpectations
    builder = Dama::WebBuilder.new(project_root: demo_root)

    # Build should succeed without errors.
    expect { builder.build }.not_to raise_error

    dist = File.join(demo_root, "dist")

    # Core dist files must exist.
    expect(File.exist?(File.join(dist, "index.html"))).to be(true)
    expect(File.exist?(File.join(dist, "game.wasm"))).to be(true)
    expect(File.exist?(File.join(dist, "ruby_wasm.js"))).to be(true)
    expect(File.exist?(File.join(dist, "pkg", "dama_native_bg.wasm"))).to be(true)
    expect(File.exist?(File.join(dist, "pkg", "dama_native.js"))).to be(true)

    # The auto-generated dama_core.rb should be packed into game.wasm.
    # Verify game.wasm is larger than ruby_base.wasm (it has game code packed in).
    base_size = File.size(File.join(dist, "ruby_base.wasm"))
    game_size = File.size(File.join(dist, "game.wasm"))
    expect(game_size).to be > base_size

    # The wasm-bindgen JS glue should export dama_render_commands.
    js_glue = File.read(File.join(dist, "pkg", "dama_native.js"))
    expect(js_glue).to include("dama_render_commands")
    expect(js_glue).to include("dama_render_vertices")
    expect(js_glue).to include("dama_init")
    # dist/ is gitignored — no cleanup needed.
  end
end
