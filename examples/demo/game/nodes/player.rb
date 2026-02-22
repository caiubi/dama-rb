class Player < Dama::Node
  component Transform, as: :transform, x: 400.0, y: 300.0, speed: 200.0

  draw do
    size = 40.0
    triangle(
      transform.x, transform.y - size,
      transform.x - size, transform.y + size,
      transform.x + size, transform.y + size,
      r: 1.0, g: 0.2, b: 0.2, a: 1.0
    )
  end
end
