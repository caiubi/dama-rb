module Dama
  # Snapshot of input state for a single frame.
  # Provides convenience methods for common input queries.
  class Input
    def initialize(backend:)
      @keyboard = Input::KeyboardState.new(backend:)
      @mouse = Input::MouseState.new(backend:)
    end

    # Generic key queries — works for any named key.
    def key_pressed?(key) = keyboard.pressed?(key:)
    def key_just_pressed?(key) = keyboard.just_pressed?(key:)

    # Keyboard convenience methods.
    def left?  = keyboard.pressed?(key: :left)
    def right? = keyboard.pressed?(key: :right)
    def up?    = keyboard.pressed?(key: :up)
    def down?  = keyboard.pressed?(key: :down)
    def space? = keyboard.pressed?(key: :space)
    def escape? = keyboard.pressed?(key: :escape)

    # Mouse convenience methods.
    def mouse_x = mouse.x
    def mouse_y = mouse.y
    def mouse_pressed?(button) = mouse.pressed?(button:)
    def mouse_just_pressed?(button) = mouse.just_pressed?(button:)
    def mouse_clicked? = mouse.just_pressed?(button: :left)

    # Must be called once per frame to track mouse button transitions.
    def update
      mouse.update
    end

    private

    attr_reader :keyboard, :mouse
  end
end
