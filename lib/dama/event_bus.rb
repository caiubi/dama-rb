module Dama
  # Publish/subscribe event system for decoupled communication
  # between game objects. Nodes and scenes can emit events and
  # register handlers without direct references.
  #
  # Usage:
  #   bus = EventBus.new
  #   bus.on(:damage) { |amount:| puts "Ouch! #{amount}" }
  #   bus.emit(:damage, amount: 10)
  class EventBus
    def initialize
      @handlers = Hash.new { |h, k| h[k] = [] }
    end

    def on(event_name, &handler)
      handlers[event_name] << handler
    end

    def once(event_name, &handler)
      wrapper = lambda { |**data|
        handler.call(**data)
        off(event_name, &wrapper)
      }
      on(event_name, &wrapper)
    end

    def emit(event_name, **data)
      handlers[event_name].each { |handler| handler.call(**data) }
    end

    def off(event_name, &handler)
      handlers[event_name].delete(handler)
    end

    def clear(event_name)
      handlers.delete(event_name)
    end

    def clear_all
      handlers.clear
    end

    private

    attr_reader :handlers
  end
end
