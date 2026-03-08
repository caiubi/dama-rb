require "spec_helper"

RSpec.describe Dama::Tween::Lerp do
  let(:target) { Struct.new(:x).new(0.0) }

  describe "#update" do
    it "interpolates the attribute from start to end over the duration" do
      tween = described_class.new(target:, attribute: :x, from: 0.0, to: 100.0, duration: 1.0)

      tween.update(delta_time: 0.5)
      expect(target.x).to eq(50.0)

      tween.update(delta_time: 0.5)
      expect(target.x).to eq(100.0)
    end

    it "clamps progress to 1.0 when elapsed exceeds duration" do
      tween = described_class.new(target:, attribute: :x, from: 10.0, to: 20.0, duration: 0.5)

      tween.update(delta_time: 1.0)
      expect(target.x).to eq(20.0)
    end

    it "handles negative direction (from > to)" do
      target.x = 100.0
      tween = described_class.new(target:, attribute: :x, from: 100.0, to: 0.0, duration: 1.0)

      tween.update(delta_time: 0.5)
      expect(target.x).to eq(50.0)
    end

    it "calls on_complete when the tween finishes" do
      completed = false
      tween = described_class.new(
        target:, attribute: :x, from: 0.0, to: 10.0, duration: 0.1,
        on_complete: -> { completed = true }
      )

      tween.update(delta_time: 0.1)
      expect(completed).to be(true)
    end

    it "does not call on_complete before finishing" do
      completed = false
      tween = described_class.new(
        target:, attribute: :x, from: 0.0, to: 10.0, duration: 1.0,
        on_complete: -> { completed = true }
      )

      tween.update(delta_time: 0.5)
      expect(completed).to be(false)
    end

    it "applies easing function when specified" do
      tween = described_class.new(
        target:, attribute: :x, from: 0.0, to: 100.0, duration: 1.0,
        easing: :ease_in_quad
      )

      tween.update(delta_time: 0.5)
      # ease_in_quad at t=0.5 = 0.25, so value = 0 + 100 * 0.25 = 25
      expect(target.x).to eq(25.0)
    end

    it "defaults to linear easing" do
      tween = described_class.new(target:, attribute: :x, from: 0.0, to: 100.0, duration: 1.0)

      tween.update(delta_time: 0.5)
      expect(target.x).to eq(50.0)
    end
  end

  describe "#complete?" do
    it "returns false while in progress" do
      tween = described_class.new(target:, attribute: :x, from: 0.0, to: 10.0, duration: 1.0)
      tween.update(delta_time: 0.5)

      expect(tween).not_to be_complete
    end

    it "returns true when elapsed >= duration" do
      tween = described_class.new(target:, attribute: :x, from: 0.0, to: 10.0, duration: 1.0)
      tween.update(delta_time: 1.0)

      expect(tween).to be_complete
    end
  end
end
