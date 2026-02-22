class Landmark < Dama::Node
  attribute :cx, default: 0.0
  attribute :cy, default: 0.0
  attribute :radius, default: 30.0
  attribute :color_r, default: 1.0
  attribute :color_g, default: 1.0
  attribute :color_b, default: 1.0

  draw do
    circle(cx, cy, radius, r: color_r, g: color_g, b: color_b, a: 1.0)
  end
end
