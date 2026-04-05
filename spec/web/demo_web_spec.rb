require "spec_helper"

RSpec.describe "Demo web build", :web do # rubocop:disable RSpec/DescribeClass
  include_context "with web game",
                  project: File.expand_path("../../examples/demo", __dir__)
  include WebTestHelpers

  before { visit "/" }

  it "loads without JS errors" do
    wait_for_game
    expect(game).to have_no_console_errors
  end

  it "exports all required wasm functions" do
    wait_for_game
    exports = game.wasm_exports
    expect(exports).to include("dama_init", "dama_render_commands", "dama_render_text",
                               "dama_begin_frame", "dama_end_frame")
  end

  it "runs multiple frames" do
    wait_for_game
    initial = game.frame_count
    sleep(1)
    expect(game.frame_count).to be > initial
  end
end
