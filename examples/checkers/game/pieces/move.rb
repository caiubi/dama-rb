# Represents a move: from one position to another, optionally
# capturing one or more opponent pieces along the way.
Move = Data.define(:from, :to, :captures) do
  def capture?
    captures.any?
  end
end
