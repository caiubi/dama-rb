RSpec.describe Dama::Input::KeyboardState do
  subject(:keyboard) { described_class.new(backend:) }

  include_context "with headless backend"

  describe "#pressed?" do
    it "returns false for an unpressed key in headless mode" do
      expect(keyboard.pressed?(key: :left)).to be(false)
    end

    it "accepts all defined key symbols" do
      Dama::Input::KeyboardState::KEY_CODES.each_key do |key|
        expect(keyboard.pressed?(key:)).to be(false)
      end
    end
  end

  describe "#just_pressed?" do
    it "returns false for a key in headless mode" do
      expect(keyboard.just_pressed?(key: :space)).to be(false)
    end
  end
end
