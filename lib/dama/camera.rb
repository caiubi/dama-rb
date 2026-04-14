module Dama
  # 2D camera with position, zoom, follow, and viewport culling.
  # All draw coordinates in a scene are translated/scaled through
  # the camera before reaching the backend.
  class Camera
    MIN_ZOOM = 0.1
    MAX_ZOOM = 10.0

    attr_reader :x, :y, :zoom, :viewport_width, :viewport_height

    def initialize(viewport_width:, viewport_height:, x: 0.0, y: 0.0, zoom: 1.0)
      @viewport_width = viewport_width.to_f
      @viewport_height = viewport_height.to_f
      @x = x.to_f
      @y = y.to_f
      @zoom = zoom.to_f.clamp(MIN_ZOOM, MAX_ZOOM)
    end

    def move_to(x:, y:)
      self.x = x.to_f
      self.y = y.to_f
    end

    def move_by(dx:, dy:)
      self.x = self.x + dx.to_f
      self.y = self.y + dy.to_f
    end

    def zoom_to(level:)
      self.zoom = level.to_f.clamp(MIN_ZOOM, MAX_ZOOM)
    end

    # Converts world coordinates to screen pixel coordinates.
    def world_to_screen(world_x:, world_y:)
      {
        screen_x: (world_x - x) * zoom,
        screen_y: (world_y - y) * zoom,
      }
    end

    # Converts screen pixel coordinates to world coordinates.
    def screen_to_world(screen_x:, screen_y:)
      {
        world_x: (screen_x / zoom) + x,
        world_y: (screen_y / zoom) + y,
      }
    end

    # Returns true if a world-space rectangle overlaps the camera viewport.
    def visible?(x:, y:, width:, height:)
      screen = world_to_screen(world_x: x, world_y: y)
      screen_w = width * zoom
      screen_h = height * zoom

      (screen.fetch(:screen_x) + screen_w).positive? &&
        screen.fetch(:screen_x) < viewport_width &&
        (screen.fetch(:screen_y) + screen_h).positive? &&
        screen.fetch(:screen_y) < viewport_height
    end

    # Centers the camera on a target object (must respond to #x and #y).
    # Use lerp < 1.0 for smooth following.
    def follow(target:, lerp: 1.0)
      self.x = self.x + ((target.x - x) * lerp)
      self.y = self.y + ((target.y - y) * lerp)
    end

    private

    attr_writer :x, :y, :zoom
  end
end
