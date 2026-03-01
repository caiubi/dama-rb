class Smiley < Dama::Node
  component Transform, as: :transform, x: 600.0, y: 200.0, speed: 150.0
  texture :face, path: File.expand_path("../../assets/smiley.png", __dir__)

  draw do
    sprite(face, transform.x - 50, transform.y - 50, 100, 100)
  end
end
