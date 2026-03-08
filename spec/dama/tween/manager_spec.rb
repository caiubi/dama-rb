require "spec_helper"

RSpec.describe Dama::Tween::Manager do
  subject(:manager) { described_class.new }

  let(:target) { Struct.new(:x, :y).new(0.0, 0.0) }

  describe "#add" do
    it "accepts a tween" do
      tween = Dama::Tween::Lerp.new(target:, attribute: :x, from: 0.0, to: 10.0, duration: 1.0)
      manager.add(tween:)

      expect(manager).to be_active
    end
  end

  describe "#update" do
    it "advances all active tweens" do
      tween_x = Dama::Tween::Lerp.new(target:, attribute: :x, from: 0.0, to: 100.0, duration: 1.0)
      tween_y = Dama::Tween::Lerp.new(target:, attribute: :y, from: 0.0, to: 200.0, duration: 1.0)
      manager.add(tween: tween_x)
      manager.add(tween: tween_y)

      manager.update(delta_time: 0.5)

      expect(target.x).to eq(50.0)
      expect(target.y).to eq(100.0)
    end

    it "removes completed tweens" do
      tween = Dama::Tween::Lerp.new(target:, attribute: :x, from: 0.0, to: 10.0, duration: 0.5)
      manager.add(tween:)

      manager.update(delta_time: 1.0)

      expect(manager).not_to be_active
    end
  end

  describe "#active?" do
    it "returns false when no tweens are registered" do
      expect(manager).not_to be_active
    end

    it "returns true when tweens are in progress" do
      tween = Dama::Tween::Lerp.new(target:, attribute: :x, from: 0.0, to: 10.0, duration: 1.0)
      manager.add(tween:)

      expect(manager).to be_active
    end
  end
end
