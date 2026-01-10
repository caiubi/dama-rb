require "zeitwerk"

module Dama
  class << self
    def loader
      @loader ||= begin
        loader = Zeitwerk::Loader.for_gem
        loader.setup
        loader
      end
    end

    def root
      File.expand_path("..", __dir__)
    end
  end
end

Dama.loader
