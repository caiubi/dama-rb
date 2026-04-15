# Web entry point: loads engine, game code, and wires up the JS frame loop.
#
# This file uses global variables ($backend, $scene, etc.) because ruby.wasm
# requires globals for JS interop — the JS frame loop invokes $dama_tick.call
# each frame, and closures over local variables don't persist across ruby.wasm
# JS boundary calls.

require "js"
require_relative "dama_core"

# Auto-load game files with retry (handles dependency ordering).
game_files = Dir["/src/game/**/*.rb"]
remaining = game_files.dup
10.times do
  failed = []
  remaining.each do |f|
    require f
  rescue NameError
    failed << f
  end
  break if failed.empty?
  break if failed.size == remaining.size

  remaining = failed
end
require "/src/config"

# Boot the game scene using the web backend.
$backend = Dama::Backend::Web.new
config = GAME.configuration
$backend.initialize_engine(configuration: config)

$asset_cache = Dama::AssetCache.new(backend: $backend)
$scene = GAME.send(:start_scene_class).new(
  registry: GAME.registry,
  asset_cache: $asset_cache,
  backend: $backend,
  scene_switcher: ->(scene_class) { $pending_scene = scene_class },
)
$scene.perform_compose
$scene.perform_enter

$input = Dama::Input.new(backend: $backend)
$pending_scene = nil

# Expose game state for integration tests and the JS error overlay.
# Error tracking (window.__damaErrors, error/unhandledrejection listeners)
# is initialized in index.html before Ruby loads, so we only set up
# the state object that the JS overlay reads for context.
JS.eval("window.__damaState = { frameCount: 0, sceneName: '' }")

$dama_tick = lambda {
  dt = $backend.delta_time
  $input.update

  $scene.perform_update(delta_time: dt, input: $input)

  # Handle scene transitions.
  if $pending_scene
    $scene = $pending_scene.new(
      registry: GAME.registry,
      asset_cache: $asset_cache,
      backend: $backend,
      scene_switcher: ->(sc) { $pending_scene = sc },
    )
    $scene.perform_compose
    $scene.perform_enter
    $pending_scene = nil
  end

  $backend.begin_frame
  $backend.clear
  $scene.perform_draw(backend: $backend)

  $backend.end_frame

  # Expose state for integration tests.
  JS.eval("window.__damaState.frameCount = #{$backend.frame_count}")
  JS.eval("window.__damaState.sceneName = '#{$scene.class.name}'")
}
