module Dama
  class Input
    # Maps symbolic key names to winit KeyCode values and queries
    # the backend for current key state.
    class KeyboardState
      # Maps symbolic key names to Dama::Keys constants.
      KEY_CODES = {
        left: Keys::ARROW_LEFT,
        right: Keys::ARROW_RIGHT,
        up: Keys::ARROW_UP,
        down: Keys::ARROW_DOWN,
        space: Keys::SPACE,
        enter: Keys::ENTER,
        escape: Keys::ESCAPE,
        a: Keys::KEY_A,
        b: Keys::KEY_B,
        c: Keys::KEY_C,
        d: Keys::KEY_D,
        w: Keys::KEY_W,
        s: Keys::KEY_S,
        equal: Keys::EQUAL,
        minus: Keys::MINUS,
      }.freeze

      def initialize(backend:)
        @backend = backend
      end

      def pressed?(key:)
        code = KEY_CODES.fetch(key)
        backend.key_pressed?(key_code: code)
      end

      def just_pressed?(key:)
        code = KEY_CODES.fetch(key)
        backend.key_just_pressed?(key_code: code)
      end

      private

      attr_reader :backend
    end
  end
end
