module Dama
  class Tween
    # Standard easing functions for use with Tween::Lerp.
    # Each function maps a progress value t (0.0..1.0) to an eased value.
    #
    # Usage:
    #   Tween::Lerp.new(target:, attribute:, from:, to:, duration:,
    #                   easing: :ease_in_out_quad)
    module Easing
      FUNCTIONS = {
        linear: ->(t) { t },

        ease_in_quad: ->(t) { t * t },
        ease_out_quad: ->(t) { t * (2.0 - t) },
        ease_in_out_quad: ->(t) { t < 0.5 ? 2.0 * t * t : -1.0 + ((4.0 - (2.0 * t)) * t) },

        ease_in_cubic: ->(t) { t * t * t },
        ease_out_cubic: ->(t) { ((t - 1.0)**3) + 1.0 },
        ease_in_out_cubic: lambda { |t|
          t < 0.5 ? 4.0 * t * t * t : ((t - 1.0) * ((2.0 * t) - 2.0) * ((2.0 * t) - 2.0)) + 1.0
        },

        ease_in_out_sine: ->(t) { -(Math.cos(Math::PI * t) - 1.0) / 2.0 },
      }.freeze

      def self.fetch(name:)
        FUNCTIONS.fetch(name)
      end
    end
  end
end
