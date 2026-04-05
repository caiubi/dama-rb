module Dama
  module Colors
    Color = Data.define(:r, :g, :b, :a) do
      def to_h = { r:, g:, b:, a: }

      def with_alpha(a:)
        self.class.new(r:, g:, b:, a:)
      end
    end

    RED        = Color.new(r: 0.9, g: 0.2, b: 0.2, a: 1.0)
    DARK_RED   = Color.new(r: 0.6, g: 0.1, b: 0.1, a: 1.0)
    WHITE      = Color.new(r: 1.0, g: 1.0, b: 1.0, a: 1.0)
    CREAM      = Color.new(r: 0.96, g: 0.93, b: 0.87, a: 1.0)
    BLACK      = Color.new(r: 0.0, g: 0.0, b: 0.0, a: 1.0)
    GRAY       = Color.new(r: 0.5, g: 0.5, b: 0.5, a: 1.0)
    DARK_BROWN = Color.new(r: 0.44, g: 0.26, b: 0.13, a: 1.0)
    LIGHT_TAN  = Color.new(r: 0.87, g: 0.72, b: 0.53, a: 1.0)
    GREEN      = Color.new(r: 0.2, g: 0.8, b: 0.3, a: 1.0)
    GOLD       = Color.new(r: 1.0, g: 0.84, b: 0.0, a: 1.0)
    YELLOW     = Color.new(r: 1.0, g: 1.0, b: 0.0, a: 1.0)
    BLUE       = Color.new(r: 0.2, g: 0.4, b: 0.9, a: 1.0)

    # Logo-derived palette — extracted from dama-logo.svg
    LIGHT_GRAY = Color.new(r: 0.96, g: 0.96, b: 0.96, a: 1.0)
    DARK_GRAY  = Color.new(r: 0.07, g: 0.07, b: 0.07, a: 1.0)
    CHARCOAL   = Color.new(r: 0.32, g: 0.35, b: 0.38, a: 1.0)
    SLATE      = Color.new(r: 0.13, g: 0.15, b: 0.17, a: 1.0)
  end
end
