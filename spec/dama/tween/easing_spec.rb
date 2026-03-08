require "spec_helper"

RSpec.describe Dama::Tween::Easing do
  describe "all easing functions" do
    described_class::FUNCTIONS.each_key do |name|
      describe ".#{name}" do
        let(:easing) { described_class.fetch(name:) }

        it "returns 0.0 at t=0" do
          expect(easing.call(0.0)).to eq(0.0)
        end

        it "returns 1.0 at t=1" do
          expect(easing.call(1.0)).to be_within(0.001).of(1.0)
        end

        it "returns a value between 0 and 1 at t=0.5" do
          result = easing.call(0.5)
          expect(result).to be_between(0.0, 1.0)
        end

        it "is monotonically increasing" do
          values = (0..10).map { |i| easing.call(i / 10.0) }
          values.each_cons(2) do |a, b|
            expect(b).to be >= a
          end
        end
      end
    end
  end

  describe ".fetch" do
    it "returns the named easing function" do
      expect(described_class.fetch(name: :linear)).to respond_to(:call)
    end

    it "raises KeyError for unknown easing" do
      expect { described_class.fetch(name: :nonexistent) }.to raise_error(KeyError)
    end
  end

  describe "specific easing curves" do
    it "linear returns t directly" do
      expect(described_class.fetch(name: :linear).call(0.5)).to eq(0.5)
    end

    it "ease_in_quad is slower at start (below linear at t=0.25)" do
      result = described_class.fetch(name: :ease_in_quad).call(0.25)
      expect(result).to be < 0.25
    end

    it "ease_out_quad is faster at start (above linear at t=0.25)" do
      result = described_class.fetch(name: :ease_out_quad).call(0.25)
      expect(result).to be > 0.25
    end

    it "ease_in_out_quad passes through 0.5 at t=0.5" do
      result = described_class.fetch(name: :ease_in_out_quad).call(0.5)
      expect(result).to be_within(0.001).of(0.5)
    end

    it "ease_in_cubic is slower than ease_in_quad at start" do
      quad = described_class.fetch(name: :ease_in_quad).call(0.25)
      cubic = described_class.fetch(name: :ease_in_cubic).call(0.25)
      expect(cubic).to be < quad
    end
  end
end
