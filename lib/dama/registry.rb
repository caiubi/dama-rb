module Dama
  # Global class registry for auto-discovery of Component, Node, and Scene
  # subclasses. Supports symbol/string-to-class resolution for the Composer DSL.
  class Registry
    def initialize
      @resolver = Registry::ClassResolver.new
    end

    def register(klass:, category:)
      resolver.register(klass:, category:)
    end

    def resolve(name:, category:)
      resolver.resolve(name:, category:)
    end

    private

    attr_reader :resolver
  end
end
