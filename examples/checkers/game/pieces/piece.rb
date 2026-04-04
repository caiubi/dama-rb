# A checker piece. Immutable — promotion returns a new piece.
Piece = Data.define(:team, :king) do
  def kinged
    with(king: true)
  end
end
