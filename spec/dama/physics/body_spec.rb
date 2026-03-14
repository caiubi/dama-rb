require "spec_helper"

RSpec.describe Dama::Physics::Body do
  subject(:body) do
    described_class.new(type: :dynamic, mass: 2.0, collider:, node:, restitution: 0.5)
  end

  let(:transform_class) do
    Class.new(Dama::Component) do
      attribute :x, default: 100.0
      attribute :y, default: 200.0
    end
  end

  let(:node_class) do
    tc = transform_class
    Class.new(Dama::Node) do
      component tc, as: :transform
    end
  end

  let(:node) { node_class.new }
  let(:collider) { Dama::Physics::Collider.rect(width: 32.0, height: 32.0) }

  describe "#type" do
    it "returns the body type" do
      expect(body.type).to eq(:dynamic)
    end

    it "responds to type predicates" do
      expect(body).to be_dynamic
      expect(body).not_to be_static
      expect(body).not_to be_kinematic
    end
  end

  describe "#x / #y" do
    it "delegates to the node's transform" do
      expect(body.x).to eq(100.0)
      expect(body.y).to eq(200.0)
    end

    it "can set position via the node's transform" do
      body.x = 50.0
      body.y = 75.0
      expect(node.transform.x).to eq(50.0)
      expect(node.transform.y).to eq(75.0)
    end
  end

  describe "#integrate" do
    it "updates position based on velocity and gravity" do
      body.velocity_x = 100.0
      body.velocity_y = 50.0

      body.integrate(delta_time: 0.1, gravity_x: 0.0, gravity_y: 500.0)

      # velocity_y += (0 + 500) * 0.1 = 50 → velocity_y = 100
      # x += 100 * 0.1 = 10 → x = 110
      # y += 100 * 0.1 = 10 → y = 210
      expect(body.x).to eq(110.0)
      expect(body.y).to eq(210.0)
      expect(body.velocity_y).to eq(100.0)
    end

    it "does not move static bodies" do
      static_body = described_class.new(type: :static, collider:, node:)
      static_body.velocity_x = 999.0

      static_body.integrate(delta_time: 1.0, gravity_x: 0.0, gravity_y: 500.0)

      expect(static_body.x).to eq(100.0) # unchanged
    end
  end
end
