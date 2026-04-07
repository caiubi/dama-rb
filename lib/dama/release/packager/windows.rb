require "fileutils"

module Dama
  module Release
    module Packager
      # Creates a self-contained Windows directory with a .bat launcher,
      # bundled Ruby, native .dll, game files, and assets.
      class Windows
        def initialize(project_root:)
          @project_root = project_root
          @metadata = GameMetadata.new(project_root:)
          @icon_provider = IconProvider.new(project_root:, platform: :windows)
        end

        def package
          native_library_path = NativeBuilder.new.build
          prepare_structure
          RubyBundler.new(destination: release_path, project_root:).bundle
          FileUtils.cp(native_library_path, release_path)
          GameFileCopier.new(project_root:, destination: release_path).copy
          copy_icon
          write_launcher_script(native_library_path:)

          puts "Windows release created: #{release_path}"
        end

        private

        attr_reader :project_root, :metadata, :icon_provider

        def release_path
          File.join(project_root, "release", metadata.release_name)
        end

        def prepare_structure
          FileUtils.rm_rf(release_path)
          FileUtils.mkdir_p(release_path)
        end

        def copy_icon
          icon_source = icon_provider.icon_path
          FileUtils.cp(icon_source, File.join(release_path, "icon.ico")) if File.exist?(icon_source)
        end

        def write_launcher_script(native_library_path:)
          launcher_path = File.join(release_path, "#{metadata.release_name}.bat")
          content = TemplateRenderer.new(
            template_name: "launcher_windows.bat.erb",
            variables: {
              native_lib_name: File.basename(native_library_path),
              ruby_version: RbConfig::CONFIG.fetch("ruby_version"),
              ruby_arch: RbConfig::CONFIG.fetch("arch"),
            },
          ).render
          File.write(launcher_path, content)
        end
      end
    end
  end
end
