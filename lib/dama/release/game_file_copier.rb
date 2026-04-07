require "fileutils"

module Dama
  module Release
    # Copies the game's source files (game/, config.rb, assets/) from
    # the project directory into the release destination. Shared across
    # all native packagers to avoid duplicating the same copy logic.
    class GameFileCopier
      def initialize(project_root:, destination:)
        @project_root = project_root
        @destination = destination
      end

      def copy
        copy_directory("game")
        copy_file("config.rb")
        copy_directory("assets")
      end

      private

      attr_reader :project_root, :destination

      def copy_directory(name)
        source = File.join(project_root, name)
        FileUtils.cp_r(source, File.join(destination, name)) if File.directory?(source)
      end

      def copy_file(name)
        source = File.join(project_root, name)
        FileUtils.cp(source, destination) if File.exist?(source)
      end
    end
  end
end
