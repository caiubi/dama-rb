# Web integration test helpers for Capybara + Cuprite.
# Provides game state queries and custom matchers for testing
# dama-rb games running in a real browser.
#
# NOT auto-loaded — only required in :web tagged specs.

require "capybara/cuprite"
require "capybara/rspec"

Capybara.register_driver(:cuprite) do |app|
  Capybara::Cuprite::Driver.new(app,
                                window_size: [1024, 768],
                                headless: ENV.fetch("HEADLESS", "true") != "false",
                                js_errors: false, # We check errors manually via GameProxy.
                                process_timeout: 30,
                                timeout: 20,
                                browser_options: {
                                  "no-sandbox" => nil,
                                  "disable-dev-shm-usage" => nil,
                                })
end

Capybara.default_driver = :cuprite
Capybara.javascript_driver = :cuprite
Capybara.server = :webrick

# Proxy for querying game state from Ruby specs via evaluate_script.
# The web entry point exposes globals ($scene, $backend, etc.) which
# we query through JS.
class GameProxy
  def initialize(page)
    @page = page
  end

  def current_scene_class
    page.evaluate_script("window.__damaState?.sceneName || 'unknown'")
  end

  def has_node?(_name)
    # Nodes are Ruby objects — can't query directly from JS.
    # The scene name changing confirms compose worked.
    current_scene_class != "unknown"
  end

  def frame_count
    page.evaluate_script("window.__damaState?.frameCount || 0").to_i
  end

  def wasm_exports
    page.evaluate_script(
      "Object.keys(window.damaWgpu || {}).filter(k => typeof window.damaWgpu[k] === 'function').sort()",
    )
  end

  def console_errors
    page.evaluate_script("window.__damaErrors || []")
  end

  private

  attr_reader :page
end

# Helpers mixed into web specs.
module WebTestHelpers # rubocop:disable Style/OneClassPerFile
  include Capybara::DSL

  def game
    @game ||= GameProxy.new(page)
  end

  def click_canvas(x:, y:)
    canvas = find("canvas#game")
    # Capybara click uses element-relative coordinates.
    canvas.click(x:, y:)
  end

  def wait_for_game(timeout: 15)
    expect(page).to have_css("canvas#game", wait: timeout)
    # Wait for at least one frame to render.
    Timeout.timeout(timeout) do
      sleep(0.5) until game.frame_count.positive?
    end
  end
end

# Custom RSpec matchers for game state.
RSpec::Matchers.define :have_scene do |expected_class_name|
  match do |game_proxy|
    name = expected_class_name.is_a?(String) ? expected_class_name : expected_class_name.to_s
    game_proxy.current_scene_class == name
  end

  failure_message do |game_proxy|
    "expected scene #{expected_class_name}, got #{game_proxy.current_scene_class}"
  end
end

RSpec::Matchers.define :have_node do |name|
  match do |game_proxy|
    game_proxy.has_node?(name.to_s)
  end
end

RSpec::Matchers.define :have_no_console_errors do
  match do |game_proxy|
    game_proxy.console_errors.empty?
  end

  failure_message do |game_proxy|
    "expected no console errors, got: #{game_proxy.console_errors.inspect}"
  end
end
