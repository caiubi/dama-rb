RSpec.describe Dama::Debug::FrameController do
  describe "unlimited mode" do
    subject(:controller) { described_class.new(frame_limit: 0) }

    it "never reports frame limit reached" do
      10.times { controller.tick }
      expect(controller.frame_limit_reached?).to be(false)
    end

    it "tracks current frame count" do
      3.times { controller.tick }
      expect(controller.current_frame).to eq(3)
    end
  end

  describe "limited mode" do
    subject(:controller) { described_class.new(frame_limit: 5) }

    it "reports false before reaching the limit" do
      3.times { controller.tick }
      expect(controller.frame_limit_reached?).to be(false)
    end

    it "reports true when the limit is reached" do
      5.times { controller.tick }
      expect(controller.frame_limit_reached?).to be(true)
    end

    it "reports true after exceeding the limit" do
      7.times { controller.tick }
      expect(controller.frame_limit_reached?).to be(true)
    end
  end
end
