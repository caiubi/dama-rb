require "spec_helper"

RSpec.describe Dama::Physics::World do
  let(:transform_class) do
    Class.new(Dama::Component) do
      attribute :x, default: 0.0
      attribute :y, default: 0.0
    end
  end

  let(:node_class) do
    tc = transform_class
    Class.new(Dama::Node) do
      component tc, as: :transform
    end
  end

  def make_body(type:, x: 0.0, y: 0.0, width: 32.0, height: 32.0, restitution: 0.0)
    node = node_class.new
    node.transform.x = x
    node.transform.y = y
    collider = Dama::Physics::Collider.rect(width:, height:)
    Dama::Physics::Body.new(type:, collider:, node:, restitution:)
  end

  describe "#step" do
    it "integrates velocity with gravity" do
      world = described_class.new(gravity_x: 0.0, gravity_y: 500.0)
      body = make_body(type: :dynamic, x: 100.0, y: 100.0)
      body.velocity_x = 50.0
      world.add(body)

      world.step(delta_time: 0.1)

      # velocity_y += 500 * 0.1 = 50
      # y += 50 * 0.1 = 5
      expect(body.x).to eq(105.0)
      expect(body.y).to eq(105.0)
    end

    it "detects and resolves rect-rect collision" do
      world = described_class.new
      body_a = make_body(type: :dynamic, x: 0.0, y: 0.0, width: 40.0, height: 40.0)
      body_b = make_body(type: :static, x: 30.0, y: 0.0, width: 40.0, height: 40.0)
      world.add(body_a)
      world.add(body_b)

      world.step(delta_time: 0.0)

      # body_a should be pushed left to resolve the 10px overlap.
      expect(body_a.x).to be < 0.0
    end

    it "resolves static-first vs dynamic collision" do
      world = described_class.new
      # Static body added first, dynamic second.
      body_static = make_body(type: :static, x: 0.0, y: 0.0, width: 40.0, height: 40.0)
      body_dynamic = make_body(type: :dynamic, x: 30.0, y: 0.0, width: 40.0, height: 40.0)
      world.add(body_static)
      world.add(body_dynamic)

      world.step(delta_time: 0.0)

      # Static should not move, dynamic should be pushed right.
      expect(body_static.x).to eq(0.0)
      expect(body_dynamic.x).to be > 30.0
    end

    it "does not move static bodies during collision" do
      world = described_class.new
      body_a = make_body(type: :dynamic, x: 0.0, y: 0.0)
      body_b = make_body(type: :static, x: 20.0, y: 0.0)
      world.add(body_a)
      world.add(body_b)

      world.step(delta_time: 0.0)

      expect(body_b.x).to eq(20.0) # static didn't move
    end

    it "splits separation for dynamic vs dynamic" do
      world = described_class.new
      body_a = make_body(type: :dynamic, x: 0.0, y: 0.0, width: 40.0, height: 40.0)
      body_b = make_body(type: :dynamic, x: 30.0, y: 0.0, width: 40.0, height: 40.0)
      world.add(body_a)
      world.add(body_b)

      world.step(delta_time: 0.0)

      # 10px overlap split: a moves -5, b moves +5
      expect(body_a.x).to be < 0.0
      expect(body_b.x).to be > 30.0
    end

    it "emits collision events via EventBus" do
      bus = Dama::EventBus.new
      collisions = []
      bus.on(:collision) { |collision:| collisions << collision }

      world = described_class.new(event_bus: bus)
      body_a = make_body(type: :dynamic, x: 0.0, y: 0.0, width: 40.0, height: 40.0)
      body_b = make_body(type: :static, x: 30.0, y: 0.0, width: 40.0, height: 40.0)
      world.add(body_a)
      world.add(body_b)

      world.step(delta_time: 0.0)

      expect(collisions.length).to eq(1)
      expect(collisions.first.body_a).to eq(body_a)
      expect(collisions.first.body_b).to eq(body_b)
    end

    it "bounces dynamic bodies based on restitution" do
      world = described_class.new
      body_a = make_body(type: :dynamic, x: 0.0, y: 0.0, width: 40.0, height: 40.0, restitution: 1.0)
      body_a.velocity_x = 100.0
      body_b = make_body(type: :static, x: 30.0, y: 0.0, width: 40.0, height: 40.0)
      world.add(body_a)
      world.add(body_b)

      world.step(delta_time: 0.0)

      # With restitution 1.0, velocity should reverse fully.
      expect(body_a.velocity_x).to be < 0.0
    end
  end

  it "bounces along y-axis when separation is vertical" do
    world = described_class.new
    body_a = make_body(type: :dynamic, x: 0.0, y: 0.0, width: 40.0, height: 40.0, restitution: 1.0)
    body_a.velocity_y = 100.0
    body_b = make_body(type: :static, x: 0.0, y: 35.0, width: 40.0, height: 40.0)
    world.add(body_a)
    world.add(body_b)

    world.step(delta_time: 0.0)

    expect(body_a.velocity_y).to be < 0.0
  end

  it "skips collision detection between two static bodies" do
    world = described_class.new
    a = make_body(type: :static, x: 0.0, y: 0.0, width: 40.0, height: 40.0)
    b = make_body(type: :static, x: 20.0, y: 0.0, width: 40.0, height: 40.0)
    world.add(a)
    world.add(b)

    # Should not crash or resolve anything — both are static.
    expect { world.step(delta_time: 0.0) }.not_to raise_error
    expect(a.x).to eq(0.0)
    expect(b.x).to eq(20.0)
  end

  it "does not resolve positions for kinematic bodies" do
    world = described_class.new
    a = make_body(type: :kinematic, x: 0.0, y: 0.0, width: 40.0, height: 40.0)
    b = make_body(type: :dynamic, x: 30.0, y: 0.0, width: 40.0, height: 40.0)
    world.add(a)
    world.add(b)

    # Kinematic vs dynamic has no resolver — no crash expected.
    expect { world.step(delta_time: 0.0) }.not_to raise_error
  end

  it "handles zero-velocity collision without bouncing" do
    world = described_class.new
    a = make_body(type: :dynamic, x: 0.0, y: 0.0, width: 40.0, height: 40.0)
    b = make_body(type: :static, x: 30.0, y: 0.0, width: 40.0, height: 40.0)
    # a has zero velocity — dot product = 0, should not bounce.
    a.velocity_x = 0.0
    world.add(a)
    world.add(b)

    world.step(delta_time: 0.0)
    expect(a.velocity_x).to eq(0.0)
  end

  describe "#remove" do
    it "removes a body from the simulation" do
      world = described_class.new
      body = make_body(type: :dynamic)
      world.add(body)
      world.remove(body)

      # Should not crash with zero bodies.
      expect { world.step(delta_time: 0.1) }.not_to raise_error
    end
  end
end
