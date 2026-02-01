module Dama
  module Backend
    PLATFORMS = {
      web: -> { Backend::Web.new },
      native: -> { Backend::Native.new },
    }.freeze

    def self.for
      platform = defined?(JS) ? :web : :native
      PLATFORMS.fetch(platform).call
    end
  end
end
