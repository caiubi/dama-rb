module Dama
  class Tween
    # Manages a collection of active tweens, updating them each
    # frame and automatically removing completed ones.
    class Manager
      def initialize
        @active_tweens = []
      end

      def add(tween:)
        active_tweens << tween
      end

      def update(delta_time:)
        active_tweens.each { |tween| tween.update(delta_time:) }
        active_tweens.reject!(&:complete?)
      end

      def active?
        active_tweens.any?
      end

      private

      attr_reader :active_tweens
    end
  end
end
