# Vertical wall on left or right side.
class SideWall < Dama::Node
  component Transform, as: :transform
  physics_body type: :static, collider: :rect, width: 20.0, height: 600.0

  draw {}
end
