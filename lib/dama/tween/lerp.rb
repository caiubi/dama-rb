module Dama
  class Tween
    # Interpolates a single attribute on a target object from a start value
    # to an end value over a given duration, with optional easing.
    class Lerp
      def initialize(target:, attribute:, from:, to:, duration:, easing: :linear, on_complete: nil)
        @target = target
        @attribute = attribute
        @from = from.to_f
        @to = to.to_f
        @duration = duration.to_f
        @elapsed = 0.0
        @easing_fn = Easing.fetch(name: easing)
        @on_complete = on_complete
      end

      def update(delta_time:)
        @elapsed += delta_time
        linear_progress = [elapsed / duration, 1.0].min
        eased_progress = easing_fn.call(linear_progress)
        value = from + ((to - from) * eased_progress)
        target.public_send(:"#{attribute}=", value)
        on_complete&.call if complete?
      end

      def complete?
        elapsed >= duration
      end

      private

      attr_reader :target, :attribute, :from, :to, :duration, :elapsed, :easing_fn, :on_complete
    end
  end
end
