require "fileutils"

module Dama
  module Release
    module Packager
      # Produces a web-deployable build by delegating to
      # WebBuilder, then copying the output to release/web/.
      class Web
        def initialize(project_root:)
          @project_root = project_root
        end

        def package(archive: true)
          builder = Dama::WebBuilder.new(project_root:)
          builder.build

          release_dir = File.join(project_root, "release", "web")
          FileUtils.rm_rf(release_dir)
          FileUtils.mkdir_p(File.dirname(release_dir))
          FileUtils.cp_r(File.join(project_root, "dist"), release_dir)

          return puts "Web release created: #{release_dir}" unless archive

          archive_path = Archiver.new(source_path: release_dir).create_zip
          puts "Web release created: #{archive_path}"
        end

        private

        attr_reader :project_root
      end
    end
  end
end
