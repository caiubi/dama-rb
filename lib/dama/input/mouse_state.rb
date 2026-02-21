module Dama
  class Input
    # Tracks mouse position and button state with edge detection.
    # Call #update once per frame before querying.
    class MouseState
      BUTTON_CODES = {
        left: 0,
        right: 1,
        middle: 2,
      }.freeze

      def initialize(backend:)
        @backend = backend
        @previous_pressed = Hash.new(false)
        @current_pressed = Hash.new(false)
      end

      def x = backend.mouse_x
      def y = backend.mouse_y

      def pressed?(button:)
        code = BUTTON_CODES.fetch(button)
        backend.mouse_button_pressed?(button: code)
      end

      # Returns true only on the frame the button transitions
      # from released to pressed (edge detection).
      def just_pressed?(button:)
        current_pressed.fetch(button, false) && !previous_pressed.fetch(button, false)
      end

      # Must be called once per frame to track state transitions.
      def update
        BUTTON_CODES.each_key do |button|
          previous_pressed[button] = current_pressed[button]
          current_pressed[button] = pressed?(button:)
        end
      end

      private

      attr_reader :backend, :previous_pressed, :current_pressed
    end
  end
end
