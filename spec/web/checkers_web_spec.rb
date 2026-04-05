require "spec_helper"

RSpec.describe "Checkers web build", :web do # rubocop:disable RSpec/DescribeClass
  include_context "with web game",
                  project: File.expand_path("../../examples/checkers", __dir__)
  include WebTestHelpers

  before { visit "/" }

  it "loads the title screen without errors" do
    wait_for_game
    expect(game).to have_no_console_errors
  end

  it "runs frames on the title screen" do
    wait_for_game
    expect(game.frame_count).to be > 0
  end

  it "transitions to game scene after clicking", :visual do
    wait_for_game
    click_canvas(x: 400, y: 300)
    sleep(2)
    expect(game).to have_scene("GameScene")
  end
end
