require "fileutils"
require "macho"
require "pathname"

module Dama
  module Release
    # Rewrites dynamic library load paths in macOS Mach-O binaries so they
    # reference bundled copies via @loader_path instead of absolute paths
    # from the build machine. This makes the app bundle portable —
    # it can run on any Mac without the original build environment.
    #
    # Uses the ruby-macho gem (maintained by Homebrew) for pure-Ruby
    # Mach-O manipulation, removing the dependency on Xcode command-line tools.
    class DylibRelinker
      SYSTEM_LIB_PATTERN = %r{\A(/usr/lib/|/System/)}

      def initialize(binary_path:, lib_destination:)
        @binary_path = binary_path
        @lib_destination = lib_destination
        @processed = Set.new
      end

      def relink
        FileUtils.mkdir_p(lib_destination)
        relink_binary(path: binary_path)
      end

      private

      attr_reader :binary_path, :lib_destination, :processed

      def relink_binary(path:)
        return if processed.include?(path)

        processed.add(path)

        non_system_libraries(path:).each do |original_path|
          lib_name = File.basename(original_path)
          dest_lib = File.join(lib_destination, lib_name)

          copy_library(source: original_path, destination: dest_lib)
          change_load_path(binary: path, old_path: original_path, lib_name:)
          relink_binary(path: dest_lib)
        end
      end

      def non_system_libraries(path:)
        binary_name = File.basename(path)

        linked_dylibs(path:).reject do |lib_path|
          SYSTEM_LIB_PATTERN.match?(lib_path) || File.basename(lib_path) == binary_name
        end
      end

      def linked_dylibs(path:)
        MachO::Tools.dylibs(path)
      end

      def copy_library(source:, destination:)
        return if File.exist?(destination)

        FileUtils.cp(source, destination)
      end

      def change_load_path(binary:, old_path:, lib_name:)
        binary_dir = Pathname.new(File.dirname(binary))
        lib_dir = Pathname.new(lib_destination)
        relative = lib_dir.relative_path_from(binary_dir)
        new_path = "@loader_path/#{relative}/#{lib_name}"

        MachO::Tools.change_install_name(binary, old_path, new_path)
      end
    end
  end
end
