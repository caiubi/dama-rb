module Dama
  module Debug
    # Captures the current render target to a PNG file.
    # Delegates to the backend's screenshot capability.
    class ScreenshotTool
      def initialize(backend:)
        @backend = backend
      end

      def capture(output_path:)
        backend.screenshot(output_path:)
      end

      private

      attr_reader :backend
    end
  end
end
