# Represents a square on the 8x8 checkerboard.
Position = Data.define(:row, :col) do
  def dark_square?
    (row + col).odd?
  end
end
