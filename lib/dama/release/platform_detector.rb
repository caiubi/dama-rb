module Dama
  module Release
    # Resolves the current OS into a platform symbol
    # used to select the correct packager.
    class PlatformDetector
      PLATFORMS = {
        "darwin" => :macos,
        "linux" => :linux,
        "mingw" => :windows,
        "mswin" => :windows,
      }.freeze

      class UnsupportedPlatformError < StandardError; end

      def self.detect
        platform_key = PLATFORMS.keys.detect { |k| RUBY_PLATFORM.include?(k) }
        raise UnsupportedPlatformError, "Unsupported platform: #{RUBY_PLATFORM}" unless platform_key

        PLATFORMS.fetch(platform_key)
      end
    end
  end
end
