module Dama
  # Named constants for keyboard key codes matching winit's KeyCode enum.
  # Use these instead of raw numeric values when querying input state.
  #
  # Values are the Rust enum discriminant indices for winit::keyboard::KeyCode.
  module Keys
    ARROW_LEFT  = 80
    ARROW_RIGHT = 81
    ARROW_UP    = 82
    ARROW_DOWN  = 79

    SPACE  = 62
    ENTER  = 57
    ESCAPE = 114

    BACKSPACE = 52
    TAB       = 63

    LEFT_SHIFT  = 60
    LEFT_CTRL   = 55
    LEFT_ALT    = 50
    RIGHT_SHIFT = 61
    RIGHT_CTRL  = 56
    RIGHT_ALT   = 51

    KEY_A = 19
    KEY_B = 20
    KEY_C = 21
    KEY_D = 22
    KEY_E = 23
    KEY_F = 24
    KEY_G = 25
    KEY_H = 26
    KEY_I = 27
    KEY_J = 28
    KEY_K = 29
    KEY_L = 30
    KEY_M = 31
    KEY_N = 32
    KEY_O = 33
    KEY_P = 34
    KEY_Q = 35
    KEY_R = 36
    KEY_S = 37
    KEY_T = 38
    KEY_U = 39
    KEY_V = 40
    KEY_W = 41
    KEY_X = 42
    KEY_Y = 43
    KEY_Z = 44

    EQUAL = 15
    MINUS = 45

    DIGIT_0 = 5
    DIGIT_1 = 6
    DIGIT_2 = 7
    DIGIT_3 = 8
    DIGIT_4 = 9
    DIGIT_5 = 10
    DIGIT_6 = 11
    DIGIT_7 = 12
    DIGIT_8 = 13
    DIGIT_9 = 14
  end
end
