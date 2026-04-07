require "cgi"
require "fileutils"

module Dama
  module Release
    module Packager
      # Creates a self-contained macOS .app bundle containing
      # the Ruby runtime, gems, native library, game code, and assets.
      class Macos
        def initialize(project_root:)
          @project_root = project_root
          @metadata = GameMetadata.new(project_root:)
          @icon_provider = IconProvider.new(project_root:, platform: :macos)
        end

        def package
          native_library_path = NativeBuilder.new.build
          prepare_app_structure
          ruby_path = RubyBundler.new(destination: resources_path, project_root:).bundle
          relink_dylibs(ruby_path:)
          FileUtils.cp(native_library_path, resources_path)
          GameFileCopier.new(project_root:, destination: resources_path).copy
          copy_icon
          write_info_plist
          write_launcher_script(native_library_path:)

          puts "macOS release created: #{app_path}"
        end

        private

        attr_reader :project_root, :metadata, :icon_provider

        def app_name
          "#{metadata.release_name}.app"
        end

        def app_path
          File.join(project_root, "release", app_name)
        end

        def contents_path
          File.join(app_path, "Contents")
        end

        def resources_path
          File.join(contents_path, "Resources")
        end

        def macos_path
          File.join(contents_path, "MacOS")
        end

        def prepare_app_structure
          FileUtils.rm_rf(app_path)
          FileUtils.mkdir_p(macos_path)
          FileUtils.mkdir_p(resources_path)
        end

        # Rewrites hardcoded absolute dylib paths in the bundled Ruby binary
        # to use @loader_path-relative references, so the .app works on any Mac.
        def relink_dylibs(ruby_path:)
          ruby_binary_name = RbConfig::CONFIG.fetch("ruby_install_name")
          ruby_binary_path = File.join(ruby_path, "bin", ruby_binary_name)
          lib_destination = File.join(ruby_path, "lib")
          DylibRelinker.new(binary_path: ruby_binary_path, lib_destination:).relink
        end

        def copy_icon
          icon_source = icon_provider.icon_path
          FileUtils.cp(icon_source, File.join(resources_path, "icon.icns")) if File.exist?(icon_source)
        end

        def write_info_plist
          content = TemplateRenderer.new(
            template_name: "info_plist.xml.erb",
            variables: { escaped_title: CGI.escapeHTML(metadata.title) },
          ).render
          File.write(File.join(contents_path, "Info.plist"), content)
        end

        def write_launcher_script(native_library_path:)
          launcher_path = File.join(macos_path, "launch")
          content = TemplateRenderer.new(
            template_name: "launcher_macos.sh.erb",
            variables: {
              native_lib_name: File.basename(native_library_path),
              ruby_version: RbConfig::CONFIG.fetch("ruby_version"),
              ruby_arch: RbConfig::CONFIG.fetch("arch"),
            },
          ).render
          File.write(launcher_path, content)
          FileUtils.chmod(0o755, launcher_path)
        end
      end
    end
  end
end
