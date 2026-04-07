module Dama
  module Release
    # Extracts game title and resolution from config.rb
    # without loading the engine. Uses regex with named groups
    # to parse the DSL statically.
    class GameMetadata
      TITLE_PATTERN = /title:\s*"(?<title>[^"]+)"/
      RESOLUTION_PATTERN = /resolution:\s*\[(?<width>\d+),\s*(?<height>\d+)\]/

      # Characters that are unsafe in filenames across macOS, Linux, and Windows.
      UNSAFE_FILENAME_CHARS = %r{[/\\:*?"<>|]}

      DEFAULT_RESOLUTION = [800, 600].freeze

      def initialize(project_root:)
        @project_root = project_root
      end

      def title
        extracted_title || directory_name
      end

      # Filesystem-safe version of title for use in release
      # directory names and .app bundle names.
      def release_name
        title.gsub(UNSAFE_FILENAME_CHARS, " ").squeeze(" ").strip
      end

      def resolution
        match = config_content.match(RESOLUTION_PATTERN)
        return DEFAULT_RESOLUTION unless match

        [Integer(match[:width]), Integer(match[:height])]
      end

      private

      attr_reader :project_root

      def extracted_title
        match = config_content.match(TITLE_PATTERN)
        match&.[](:title)
      end

      def directory_name
        File.basename(project_root)
      end

      def config_content
        @config_content ||= read_config
      end

      def read_config
        config_path = File.join(project_root, "config.rb")
        return "" unless File.exist?(config_path)

        File.read(config_path)
      end
    end
  end
end
