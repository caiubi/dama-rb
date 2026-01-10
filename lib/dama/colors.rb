module Dama
  module Colors
    Color = Data.define(:r, :g, :b, :a) do
      def to_h = { r:, g:, b:, a: }

      def with_alpha(a:)
        self.class.new(r:, g:, b:, a:)
      end
    end

    RED   = Color.new(r: 0.9, g: 0.2, b: 0.2, a: 1.0)
    WHITE = Color.new(r: 1.0, g: 1.0, b: 1.0, a: 1.0)
    BLACK = Color.new(r: 0.0, g: 0.0, b: 0.0, a: 1.0)
    GRAY  = Color.new(r: 0.5, g: 0.5, b: 0.5, a: 1.0)
    GREEN = Color.new(r: 0.2, g: 0.8, b: 0.3, a: 1.0)
    BLUE  = Color.new(r: 0.2, g: 0.4, b: 0.9, a: 1.0)
  end
end
