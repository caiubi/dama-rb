module Dama
  module Physics
    # Collision shape attached to a physics body.
    # Supports AABB rectangles and circles.
    # Positions (ax, ay, bx, by) are the top-left corner for rects
    # and center for circles.
    class Collider
      attr_reader :shape, :width, :height, :radius

      OVERLAP_DISPATCH = {
        %i[rect rect] => :overlap_rect_rect?,
        %i[circle circle] => :overlap_circle_circle?,
        %i[rect circle] => :overlap_rect_circle?,
        %i[circle rect] => :overlap_circle_rect?,
      }.freeze

      SEPARATION_DISPATCH = {
        %i[rect rect] => :separate_rect_rect,
        %i[circle circle] => :separate_circle_circle,
        %i[rect circle] => :separate_rect_circle,
        %i[circle rect] => :separate_circle_rect,
      }.freeze

      def self.rect(width:, height:)
        new(shape: :rect, width:, height:, radius: 0.0)
      end

      def self.circle(radius:)
        new(shape: :circle, width: 0.0, height: 0.0, radius:)
      end

      def initialize(shape:, width:, height:, radius:)
        @shape = shape
        @width = width.to_f
        @height = height.to_f
        @radius = radius.to_f
      end

      def overlap?(other:, ax:, ay:, bx:, by:)
        key = [shape, other.shape]
        method_name = OVERLAP_DISPATCH.fetch(key)
        send(method_name, other, ax, ay, bx, by)
      end

      def separation(other:, ax:, ay:, bx:, by:)
        key = [shape, other.shape]
        method_name = SEPARATION_DISPATCH.fetch(key, nil)
        return nil unless method_name

        send(method_name, other, ax, ay, bx, by)
      end

      private

      def overlap_rect_rect?(other, ax, ay, bx, by)
        ax + width > bx && ax < bx + other.width &&
          ay + height > by && ay < by + other.height
      end

      def overlap_circle_circle?(other, ax, ay, bx, by)
        dx = bx - ax
        dy = by - ay
        dist_sq = (dx * dx) + (dy * dy)
        max_dist = radius + other.radius
        dist_sq < max_dist * max_dist
      end

      def overlap_rect_circle?(other, ax, ay, bx, by)
        closest_x = bx.clamp(ax, ax + width)
        closest_y = by.clamp(ay, ay + height)
        dx = bx - closest_x
        dy = by - closest_y
        (dx * dx) + (dy * dy) < other.radius * other.radius
      end

      def overlap_circle_rect?(other, ax, ay, bx, by)
        other.overlap?(other: self, ax: bx, ay: by, bx: ax, by: ay)
      end

      def separate_circle_circle(other, ax, ay, bx, by)
        return nil unless overlap_circle_circle?(other, ax, ay, bx, by)

        dx = bx - ax
        dy = by - ay
        dist = Math.sqrt((dx * dx) + (dy * dy))

        return { dx: radius + other.radius, dy: 0.0 } if dist < 0.0001

        overlap = (radius + other.radius) - dist
        nx = dx / dist
        ny = dy / dist
        { dx: overlap * nx, dy: overlap * ny }
      end

      def separate_rect_circle(other, ax, ay, bx, by)
        return nil unless overlap_rect_circle?(other, ax, ay, bx, by)

        closest_x = bx.clamp(ax, ax + width)
        closest_y = by.clamp(ay, ay + height)
        dx = bx - closest_x
        dy = by - closest_y
        dist = Math.sqrt((dx * dx) + (dy * dy))

        return { dx: other.radius, dy: 0.0 } if dist < 0.0001

        overlap = other.radius - dist
        nx = dx / dist
        ny = dy / dist
        { dx: overlap * nx, dy: overlap * ny }
      end

      def separate_circle_rect(other, ax, ay, bx, by)
        result = other.separation(other: self, ax: bx, ay: by, bx: ax, by: ay)
        return nil unless result

        { dx: -result.fetch(:dx), dy: -result.fetch(:dy) }
      end

      def separate_rect_rect(other, ax, ay, bx, by) # rubocop:disable Metrics/AbcSize
        return nil unless overlap_rect_rect?(other, ax, ay, bx, by)

        overlap_x = (ax + width) < (bx + other.width) ? (ax + width - bx) : (bx + other.width - ax)
        overlap_y = (ay + height) < (by + other.height) ? (ay + height - by) : (by + other.height - ay)

        center_ax = ax + (width / 2.0)
        center_bx = bx + (other.width / 2.0)
        center_ay = ay + (height / 2.0)
        center_by = by + (other.height / 2.0)

        sign_x = center_bx >= center_ax ? 1.0 : -1.0
        sign_y = center_by >= center_ay ? 1.0 : -1.0

        return { dx: overlap_x * sign_x, dy: 0.0 } if overlap_x.abs <= overlap_y.abs

        { dx: 0.0, dy: overlap_y * sign_y }
      end
    end
  end
end
