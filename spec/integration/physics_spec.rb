require "spec_helper"

RSpec.describe "Physics integration" do
  let(:registry) { Dama::Registry.new }

  let(:transform_class) do
    Class.new(Dama::Component) do
      attribute :x, default: 0.0
      attribute :y, default: 0.0
    end
  end

  before { stub_const("Transform", transform_class) }

  describe "gravity and collision" do
    it "applies gravity and resolves collisions with static bodies" do
      stub_const("Player", Class.new(Dama::Node) do
        component Transform, as: :transform, x: 100.0, y: 0.0
        physics_body type: :dynamic, mass: 1.0, collider: :rect, width: 20.0, height: 20.0, restitution: 0.0
      end)

      stub_const("Floor", Class.new(Dama::Node) do
        component Transform, as: :transform, x: 0.0, y: 100.0
        physics_body type: :static, collider: :rect, width: 800.0, height: 20.0
      end)

      scene_class = Class.new(Dama::Scene) do
        compose do
          physics gravity: [0.0, 500.0]
          add Player, as: :player
          add Floor, as: :floor
        end
      end

      scene = scene_class.new(registry:)
      scene.perform_compose

      # Step several frames — player should fall toward floor.
      10.times { scene.perform_update(delta_time: 0.05, input: nil) }

      player_y = scene.player.transform.y
      # Player should have fallen but stopped at or above the floor.
      expect(player_y).to be > 0.0
      expect(player_y).to be <= 100.0
    end
  end

  describe "on_collision callback" do
    it "fires when two named bodies collide" do
      stub_const("BoxA", Class.new(Dama::Node) do
        component Transform, as: :transform, x: 0.0, y: 0.0
        physics_body type: :dynamic, collider: :rect, width: 40.0, height: 40.0
      end)

      stub_const("BoxB", Class.new(Dama::Node) do
        component Transform, as: :transform, x: 30.0, y: 0.0
        physics_body type: :static, collider: :rect, width: 40.0, height: 40.0
      end)

      collided = false

      scene_class = Class.new(Dama::Scene) do
        compose do
          physics gravity: [0.0, 0.0]
          add BoxA, as: :box_a
          add BoxB, as: :box_b
        end

        enter do
          on_collision(:box_a, :box_b) { collided = true }
        end
      end

      scene = scene_class.new(registry:)
      scene.perform_compose
      scene.perform_enter

      # Bodies overlap at initial positions — collision should fire on first step.
      scene.perform_update(delta_time: 0.016, input: nil)

      expect(collided).to be(true)
    end
  end

  describe "circle collider" do
    it "detects circle-circle collisions" do
      stub_const("BallA", Class.new(Dama::Node) do
        component Transform, as: :transform, x: 0.0, y: 0.0
        physics_body type: :dynamic, collider: :circle, radius: 20.0
      end)

      stub_const("BallB", Class.new(Dama::Node) do
        component Transform, as: :transform, x: 30.0, y: 0.0
        physics_body type: :static, collider: :circle, radius: 20.0
      end)

      collided = false

      scene_class = Class.new(Dama::Scene) do
        compose do
          physics gravity: [0.0, 0.0]
          add BallA, as: :ball_a
          add BallB, as: :ball_b
        end

        enter do
          on_collision(:ball_a, :ball_b) { collided = true }
        end
      end

      scene = scene_class.new(registry:)
      scene.perform_compose
      scene.perform_enter
      scene.perform_update(delta_time: 0.016, input: nil)

      expect(collided).to be(true)
    end
  end

  describe "bouncing" do
    it "reverses velocity on collision with restitution 1.0" do
      stub_const("Ball", Class.new(Dama::Node) do
        component Transform, as: :transform, x: 0.0, y: 0.0
        physics_body type: :dynamic, collider: :rect, width: 20.0, height: 20.0, restitution: 1.0
      end)

      stub_const("Wall", Class.new(Dama::Node) do
        component Transform, as: :transform, x: 15.0, y: 0.0
        physics_body type: :static, collider: :rect, width: 20.0, height: 20.0
      end)

      scene_class = Class.new(Dama::Scene) do
        compose do
          physics gravity: [0.0, 0.0]
          add Ball, as: :ball
          add Wall, as: :wall
        end
      end

      scene = scene_class.new(registry:)
      scene.perform_compose

      # Give ball rightward velocity.
      scene.ball.physics.velocity_x = 200.0

      scene.perform_update(delta_time: 0.0, input: nil)

      # Velocity should have reversed.
      expect(scene.ball.physics.velocity_x).to be < 0.0
    end
  end

  describe "collision with unnamed body" do
    it "does not crash when a colliding body has no named node" do
      stub_const("NamedBox", Class.new(Dama::Node) do
        component Transform, as: :transform, x: 0.0, y: 0.0
        physics_body type: :dynamic, collider: :rect, width: 40.0, height: 40.0
      end)

      scene_class = Class.new(Dama::Scene) do
        compose do
          physics gravity: [0.0, 0.0]
          add NamedBox, as: :named
        end
      end

      scene = scene_class.new(registry:)
      scene.perform_compose

      # Manually add an unnamed body that overlaps the named one.
      unnamed_node = Class.new(Dama::Node) do
        component Transform, as: :transform, x: 20.0, y: 0.0
      end.new
      collider = Dama::Physics::Collider.rect(width: 40.0, height: 40.0)
      unnamed_body = Dama::Physics::Body.new(type: :static, collider:, node: unnamed_node)
      scene.send(:physics_world).add(body: unnamed_body)

      # Should not crash — dispatch_collision returns early for unnamed bodies.
      expect { scene.perform_update(delta_time: 0.016, input: nil) }.not_to raise_error
    end
  end

  describe "removing physics nodes" do
    it "removes the physics body from the world when a node is removed" do
      stub_const("PhysBox", Class.new(Dama::Node) do
        component Transform, as: :transform, x: 0.0, y: 0.0
        physics_body type: :dynamic, collider: :rect, width: 40.0, height: 40.0
      end)

      scene_class = Class.new(Dama::Scene) do
        compose do
          physics gravity: [0.0, 0.0]
          add PhysBox, as: :phys_box
        end
      end

      scene = scene_class.new(registry:)
      scene.perform_compose

      expect(scene.phys_box.physics).not_to be_nil

      # Remove the node — physics body should also be removed.
      scene.remove(:phys_box)

      # Should not crash when stepping without the removed body.
      expect { scene.perform_update(delta_time: 0.016, input: nil) }.not_to raise_error
    end

    it "handles removing a physics node from a scene without physics world" do
      # A node with physics_body declaration but the scene has no `physics` enabled.
      stub_const("OrphanPhys", Class.new(Dama::Node) do
        component Transform, as: :transform
        physics_body type: :dynamic, collider: :rect, width: 20.0, height: 20.0
      end)

      scene_class = Class.new(Dama::Scene) do
        compose do
          add OrphanPhys, as: :orphan
        end
      end

      scene = scene_class.new(registry:)
      scene.perform_compose

      # Manually set physics on the node (simulates external assignment).
      collider = Dama::Physics::Collider.rect(width: 20.0, height: 20.0)
      scene.orphan.node.physics = Dama::Physics::Body.new(
        type: :dynamic, collider:, node: scene.orphan.node,
      )

      # Remove should not crash even though physics_world is nil.
      expect { scene.remove(:orphan) }.not_to raise_error
    end

    it "handles removing a node without a physics body" do
      stub_const("NoPhysNode", Class.new(Dama::Node) do
        component Transform, as: :transform
      end)

      scene_class = Class.new(Dama::Scene) do
        compose do
          physics gravity: [0.0, 0.0]
          add NoPhysNode, as: :no_phys
        end
      end

      scene = scene_class.new(registry:)
      scene.perform_compose

      expect { scene.remove(:no_phys) }.not_to raise_error
    end
  end

  describe "scene without physics" do
    it "works normally when physics is not enabled" do
      stub_const("SimpleNode", Class.new(Dama::Node) do
        component Transform, as: :transform
      end)

      scene_class = Class.new(Dama::Scene) do
        compose do
          add SimpleNode, as: :thing
        end
      end

      scene = scene_class.new(registry:)
      scene.perform_compose

      # No physics world — should not crash.
      expect { scene.perform_update(delta_time: 0.016, input: nil) }.not_to raise_error
    end
  end
end
