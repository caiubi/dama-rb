# Invisible wall boundary. Static physics body, no draw.
class Wall < Dama::Node
  component Transform, as: :transform
  physics_body type: :static, collider: :rect, width: 800.0, height: 20.0

  draw {}
end
