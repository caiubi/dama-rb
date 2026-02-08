module Dama
  class Node
    # Evaluation context for a Node's draw block. Provides drawing
    # primitives (rect, triangle, circle) and exposes all node
    # attributes and component accessors as direct methods.
    #
    # When a camera is present, all coordinates are automatically
    # transformed from world space to screen space.
    class DrawContext
      def initialize(node:, backend:, camera: nil)
        @node = node
        @backend = backend
        @camera = camera
      end

      def rect(x, y, w, h, color: Dama::Colors::WHITE, r: color.r, g: color.g, b: color.b, a: color.a)
        sx, sy = apply_camera(x, y)
        sw = w * zoom_factor
        sh = h * zoom_factor
        backend.draw_rect(x: sx, y: sy, w: sw, h: sh, r:, g:, b:, a:)
      end

      def triangle(x1, y1, x2, y2, x3, y3, color: Dama::Colors::WHITE, r: color.r, g: color.g, b: color.b, a: color.a)
        sx1, sy1 = apply_camera(x1, y1)
        sx2, sy2 = apply_camera(x2, y2)
        sx3, sy3 = apply_camera(x3, y3)
        backend.draw_triangle(x1: sx1, y1: sy1, x2: sx2, y2: sy2, x3: sx3, y3: sy3, r:, g:, b:, a:)
      end

      def circle(cx, cy, radius, color: Dama::Colors::WHITE, r: color.r, g: color.g, b: color.b, a: color.a, segments: 32)
        sx, sy = apply_camera(cx, cy)
        backend.draw_circle(cx: sx, cy: sy, radius: radius * zoom_factor, r:, g:, b:, a:, segments:)
      end

      def text(content, x, y, size: 24.0, color: Dama::Colors::WHITE, r: color.r, g: color.g, b: color.b, a: color.a)
        sx, sy = apply_camera(x, y)
        backend.draw_text(text: content.to_s, x: sx, y: sy, size: size * zoom_factor, r:, g:, b:, a:)
      end

      def method_missing(method_name, ...)
        return super unless node.respond_to?(method_name)

        node.public_send(method_name, ...)
      end

      def respond_to_missing?(method_name, include_private = false)
        node.respond_to?(method_name, include_private) || super
      end

      private

      attr_reader :node, :backend, :camera

      def apply_camera(world_x, world_y)
        return [world_x, world_y] unless camera

        result = camera.world_to_screen(world_x:, world_y:)
        [result.fetch(:screen_x), result.fetch(:screen_y)]
      end

      def zoom_factor
        camera ? camera.zoom : 1.0
      end
    end
  end
end
