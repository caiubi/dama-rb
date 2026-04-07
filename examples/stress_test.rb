#!/usr/bin/env ruby

# Performance stress test: progressively spawns bouncing shapes until FPS drops.
# Measures entity throughput on the native renderer.

require_relative "../lib/dama"

backend = Dama::Backend::Native.new
config = Dama::Configuration.new(width: 800, height: 600, title: "Stress Test")
backend.initialize_engine(configuration: config)

WIDTH = 800.0
HEIGHT = 600.0
BATCH_SIZE = 200
SPAWN_INTERVAL = 0.5 # seconds between batches
FPS_FLOOR = 30 # stop spawning below this

# Each entity: position, velocity, size, color, shape type.
Entity = Struct.new(:x, :y, :vx, :vy, :size, :r, :g, :b, :shape)
SHAPES = [:triangle, :rect, :circle].freeze

entities = []
spawn_timer = 0.0
stopped = false
fps = 0.0
fps_samples = []
ruby_time_ms = 0.0
frame_num = 0

input = Dama::Input.new(backend:)

puts "Stress test: spawning #{BATCH_SIZE} entities every #{SPAWN_INTERVAL}s until FPS < #{FPS_FLOOR}"
puts "Press Escape to quit, Space to toggle spawning"
puts ""

loop do
  quit = backend.poll_events
  break if quit

  dt = backend.delta_time
  dt = 0.016 if dt <= 0 || dt > 0.5

  # FPS calculation (rolling average over 30 frames).
  fps_samples << dt
  fps_samples.shift if fps_samples.length > 30
  avg_dt = fps_samples.sum / fps_samples.length
  fps = 1.0 / avg_dt

  # Spawn new entities periodically.
  spawn_timer += dt
  auto_stop = fps < FPS_FLOOR && entities.length > BATCH_SIZE
  stopped = true if auto_stop

  if !stopped && spawn_timer >= SPAWN_INTERVAL
    spawn_timer = 0.0
    BATCH_SIZE.times do
      entities << Entity.new(
        rand * WIDTH, rand * HEIGHT,
        (rand - 0.5) * 300, (rand - 0.5) * 300,
        8 + rand * 16,
        rand, rand, rand,
        SHAPES.sample
      )
    end
  end

  # Toggle spawning with Space.
  stopped = !stopped if backend.key_just_pressed?(key_code: Dama::Keys::SPACE)
  break if backend.key_pressed?(key_code: Dama::Keys::ESCAPE)

  # Update: bounce entities off walls.
  ruby_start = Process.clock_gettime(Process::CLOCK_MONOTONIC)

  entities.each do |e|
    e.x += e.vx * dt
    e.y += e.vy * dt
    e.vx = -e.vx if e.x < 0 || e.x > WIDTH
    e.vy = -e.vy if e.y < 0 || e.y > HEIGHT
    e.x = e.x.clamp(0, WIDTH)
    e.y = e.y.clamp(0, HEIGHT)
  end

  ruby_update_time = Process.clock_gettime(Process::CLOCK_MONOTONIC) - ruby_start

  # Draw.
  backend.begin_frame
  backend.clear(r: 0.05, g: 0.05, b: 0.08, a: 1.0)

  ruby_draw_start = Process.clock_gettime(Process::CLOCK_MONOTONIC)

  entities.each do |e|
    case e.shape
    when :triangle
      backend.draw_triangle(
        x1: e.x, y1: e.y - e.size,
        x2: e.x - e.size, y2: e.y + e.size,
        x3: e.x + e.size, y3: e.y + e.size,
        r: e.r, g: e.g, b: e.b, a: 1.0
      )
    when :rect
      backend.draw_rect(x: e.x - e.size, y: e.y - e.size, w: e.size * 2, h: e.size * 2,
                        r: e.r, g: e.g, b: e.b, a: 1.0)
    when :circle
      backend.draw_circle(cx: e.x, cy: e.y, radius: e.size,
                          r: e.r, g: e.g, b: e.b, a: 1.0, segments: 16)
    end
  end

  ruby_draw_time = Process.clock_gettime(Process::CLOCK_MONOTONIC) - ruby_draw_start
  ruby_time_ms = ((ruby_update_time + ruby_draw_time) * 1000).round(1)

  # HUD overlay.
  status = stopped ? (auto_stop ? "STOPPED (FPS floor)" : "PAUSED") : "SPAWNING"
  backend.draw_text(text: "FPS: #{fps.round} | Entities: #{entities.length} | Ruby: #{ruby_time_ms}ms | #{status}",
                    x: 10.0, y: 10.0, size: 18.0, r: 1.0, g: 1.0, b: 0.0, a: 1.0)
  backend.draw_text(text: "Space=pause  Esc=quit",
                    x: 10.0, y: 34.0, size: 14.0, r: 0.6, g: 0.6, b: 0.6, a: 1.0)

  backend.end_frame

  # Print stats every 60 frames.
  frame_num += 1
  if frame_num % 60 == 0
    puts "Entities: #{entities.length.to_s.rjust(6)} | FPS: #{fps.round.to_s.rjust(4)} | Ruby: #{ruby_time_ms}ms"
  end
end

backend.shutdown
puts ""
puts "=== Final Results ==="
puts "Entities: #{entities.length}"
puts "FPS: #{fps.round}"
puts "Ruby time: #{ruby_time_ms}ms/frame"
