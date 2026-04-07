module Dama
  class Cli
    # Entry point for `bin/dama release`.
    # Resolves the target platform from args or auto-detection,
    # then dispatches to the appropriate packager via Hash lookup.
    class Release
      PACKAGERS = {
        web: Dama::Release::Packager::Web,
        macos: Dama::Release::Packager::Macos,
        linux: Dama::Release::Packager::Linux,
        windows: Dama::Release::Packager::Windows,
      }.freeze

      # Maps explicit CLI arguments to platform symbols.
      # Falls back to auto-detection when the arg is not recognized.
      PLATFORM_RESOLVERS = {
        "web" => -> { :web },
      }.freeze

      DEFAULT_RESOLVER = -> { Dama::Release::PlatformDetector.detect }

      def self.run(args:, root:)
        new(args:, root:).execute
      end

      def initialize(args:, root:)
        @args = args
        @root = root
      end

      def execute
        packager_class = PACKAGERS.fetch(platform)
        packager_class.new(project_root: root).package
      end

      private

      attr_reader :args, :root

      def platform
        PLATFORM_RESOLVERS.fetch(args.first, DEFAULT_RESOLVER).call
      end
    end
  end
end
