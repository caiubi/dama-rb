module Dama
  module Release
    # Resolves the icon file for a release build.
    # Checks for a user-provided icon in assets/ first,
    # then falls back to the default icon shipped with the gem.
    class IconProvider
      ICON_EXTENSIONS = {
        macos: "icns",
        linux: "png",
        windows: "ico",
      }.freeze

      DEFAULT_ICONS_PATH = ->(ext) { File.expand_path("defaults/icon.#{ext}", __dir__) }

      def initialize(project_root:, platform:)
        @project_root = project_root
        @platform = platform
      end

      def icon_path
        user_icon_path = File.join(project_root, "assets", "icon.#{extension}")
        return user_icon_path if File.exist?(user_icon_path)

        DEFAULT_ICONS_PATH.call(extension)
      end

      private

      attr_reader :project_root, :platform

      def extension
        ICON_EXTENSIONS.fetch(platform)
      end
    end
  end
end
