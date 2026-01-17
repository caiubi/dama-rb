require "spec_helper"

RSpec.describe Dama::EventBus do
  subject(:bus) { described_class.new }

  describe "#on" do
    it "registers a handler for an event" do
      handled = false
      bus.on(:jump) { handled = true }
      bus.emit(:jump)

      expect(handled).to be(true)
    end
  end

  describe "#emit" do
    it "calls all handlers for the event" do
      results = []
      bus.on(:hit) { results << :first }
      bus.on(:hit) { results << :second }
      bus.emit(:hit)

      expect(results).to eq(%i[first second])
    end

    it "passes keyword data to handlers" do
      received = nil
      bus.on(:damage) { |amount:, source:| received = { amount:, source: } }
      bus.emit(:damage, amount: 10, source: :enemy)

      expect(received).to eq({ amount: 10, source: :enemy })
    end

    it "does nothing for events with no handlers" do
      expect { bus.emit(:nonexistent) }.not_to raise_error
    end
  end

  describe "#off" do
    it "removes a specific handler" do
      called = false
      handler = -> { called = true }
      bus.on(:test, &handler)
      bus.off(:test, &handler)
      bus.emit(:test)

      expect(called).to be(false)
    end
  end

  describe "#clear" do
    it "removes all handlers for an event" do
      results = []
      bus.on(:test) { results << 1 }
      bus.on(:test) { results << 2 }
      bus.clear(:test)
      bus.emit(:test)

      expect(results).to be_empty
    end
  end

  describe "#clear_all" do
    it "removes all handlers for all events" do
      results = []
      bus.on(:a) { results << :a }
      bus.on(:b) { results << :b }
      bus.clear_all
      bus.emit(:a)
      bus.emit(:b)

      expect(results).to be_empty
    end
  end

  describe "#once" do
    it "fires the handler only once then removes it" do
      count = 0
      bus.once(:ping) { count += 1 }
      bus.emit(:ping)
      bus.emit(:ping)

      expect(count).to eq(1)
    end
  end
end
