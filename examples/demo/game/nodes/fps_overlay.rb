class FpsOverlay < Dama::Node
  attribute :fps, default: 0.0

  draw do
    text("FPS: #{fps.round}", 10.0, 10.0, size: 20.0, r: 1.0, g: 1.0, b: 0.0, a: 1.0)
  end
end
