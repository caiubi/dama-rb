require "spec_helper"

RSpec.describe Dama::Animation do
  describe "#initialize" do
    it "creates an animation with frame range and speed" do
      anim = described_class.new(frames: 0..3, fps: 10.0)

      expect(anim.current_frame).to eq(0)
      expect(anim.fps).to eq(10.0)
    end
  end

  describe "#update" do
    it "advances frames based on elapsed time" do
      anim = described_class.new(frames: 0..3, fps: 10.0)

      anim.update(delta_time: 0.1)
      expect(anim.current_frame).to eq(1)

      anim.update(delta_time: 0.1)
      expect(anim.current_frame).to eq(2)
    end

    it "does not advance when delta_time is too small for a frame" do
      anim = described_class.new(frames: 0..3, fps: 10.0)

      anim.update(delta_time: 0.01)
      expect(anim.current_frame).to eq(0)
    end

    it "loops back to first frame after last" do
      anim = described_class.new(frames: 0..2, fps: 10.0)

      3.times { anim.update(delta_time: 0.1) }
      expect(anim.current_frame).to eq(0)
    end

    it "does not loop when loop: false" do
      anim = described_class.new(frames: 0..2, fps: 10.0, loop: false)

      5.times { anim.update(delta_time: 0.1) }
      expect(anim.current_frame).to eq(2)
    end

    it "calls on_complete when non-looping animation ends" do
      completed = false
      anim = described_class.new(
        frames: 0..1, fps: 10.0, loop: false,
        on_complete: -> { completed = true }
      )

      2.times { anim.update(delta_time: 0.1) }
      expect(completed).to be(true)
    end
  end

  describe "#complete?" do
    it "returns false for looping animations" do
      anim = described_class.new(frames: 0..2, fps: 10.0)

      5.times { anim.update(delta_time: 0.1) }
      expect(anim).not_to be_complete
    end

    it "returns true when non-looping animation finishes" do
      anim = described_class.new(frames: 0..1, fps: 10.0, loop: false)

      2.times { anim.update(delta_time: 0.1) }
      expect(anim).to be_complete
    end
  end

  describe "#reset" do
    it "resets to the first frame" do
      anim = described_class.new(frames: 0..3, fps: 10.0)

      3.times { anim.update(delta_time: 0.1) }
      anim.reset

      expect(anim.current_frame).to eq(0)
    end
  end
end
