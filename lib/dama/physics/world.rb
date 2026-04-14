module Dama
  module Physics
    # Manages physics bodies and steps the simulation each frame.
    # Integrates velocity, detects AABB/circle collisions, resolves overlaps,
    # and emits collision events via EventBus.
    class World
      attr_reader :gravity_x, :gravity_y

      def initialize(gravity_x: 0.0, gravity_y: 0.0, event_bus: nil)
        @gravity_x = gravity_x.to_f
        @gravity_y = gravity_y.to_f
        @event_bus = event_bus
        @bodies = []
      end

      def add(body:)
        bodies << body
      end

      def remove(body:)
        bodies.delete(body)
      end

      # Step the simulation: integrate velocities, detect and resolve collisions.
      def step(delta_time:)
        integrate_bodies(delta_time:)
        detect_and_resolve_collisions
      end

      private

      attr_reader :bodies, :event_bus

      def integrate_bodies(delta_time:)
        bodies.each do |body|
          body.integrate(delta_time:, gravity_x:, gravity_y:)
        end
      end

      def detect_and_resolve_collisions
        bodies.combination(2).each do |body_a, body_b|
          next if body_a.static? && body_b.static?

          sep = body_a.collider.separation(
            other: body_b.collider,
            ax: body_a.x, ay: body_a.y,
            bx: body_b.x, by: body_b.y
          )
          next unless sep

          resolve_collision(body_a, body_b, sep)
          emit_collision(body_a, body_b, sep)
        end
      end

      def resolve_collision(body_a, body_b, sep)
        dx = sep.fetch(:dx)
        dy = sep.fetch(:dy)

        resolve_positions(body_a, body_b, dx, dy)
        resolve_velocities(body_a, body_b, dx, dy)
      end

      POSITION_RESOLVERS = {
        # dynamic vs static: push dynamic body away (opposite of separation)
        %i[dynamic static] => lambda { |a, _b, dx, dy|
          a.x -= dx
          a.y -= dy
        },
        # static vs dynamic: push dynamic body along separation
        %i[static dynamic] => lambda { |_a, b, dx, dy|
          b.x += dx
          b.y += dy
        },
        # dynamic vs dynamic: split the separation equally
        %i[dynamic dynamic] => lambda { |a, b, dx, dy|
          half_dx = dx / 2.0
          half_dy = dy / 2.0
          a.x -= half_dx
          a.y -= half_dy
          b.x += half_dx
          b.y += half_dy
        },
      }.freeze

      def resolve_positions(body_a, body_b, dx, dy)
        key = [body_a.type, body_b.type]
        resolver = POSITION_RESOLVERS.fetch(key, nil)
        resolver&.call(body_a, body_b, dx, dy)
      end

      def resolve_velocities(body_a, body_b, dx, dy)
        normal_x = dx.zero? ? 0.0 : (dx / dx.abs)
        normal_y = dy.zero? ? 0.0 : (dy / dy.abs)

        # body_a bounces against normal pointing away from b (negative).
        bounce_body(body_a, -normal_x, -normal_y) if body_a.dynamic?
        # body_b bounces against normal pointing away from a (positive).
        bounce_body(body_b, normal_x, normal_y) if body_b.dynamic?
      end

      def bounce_body(body, normal_x, normal_y)
        restitution = body.restitution
        dot = (body.velocity_x * normal_x) + (body.velocity_y * normal_y)
        return unless dot.negative? # Only bounce if moving toward the surface.

        body.velocity_x -= (1.0 + restitution) * dot * normal_x
        body.velocity_y -= (1.0 + restitution) * dot * normal_y
      end

      def emit_collision(body_a, body_b, sep)
        return unless event_bus

        collision = Collision.new(
          body_a:, body_b:,
          separation_x: sep.fetch(:dx),
          separation_y: sep.fetch(:dy)
        )
        event_bus.emit(:collision, collision:)
      end
    end
  end
end
