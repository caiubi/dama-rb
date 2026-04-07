require "fileutils"
require "zip"
require "zlib"

module Dama
  module Release
    # Creates distributable archives from release directories.
    # Uses pure Ruby for tar.gz and zip formats. The macOS .app
    # variant uses ditto to preserve extended attributes and
    # resource forks -- no Ruby equivalent exists for this.
    class Archiver
      def initialize(source_path:)
        @source_path = source_path
      end

      # Creates a .zip using ditto, which preserves macOS extended
      # attributes and resource forks required by .app bundles.
      def create_macos_zip
        archive_path = "#{source_path}.zip"
        FileUtils.rm_f(archive_path)
        success = system("ditto", "-c", "-k", "--sequesterRsrc", "--keepParent", source_path, archive_path)
        raise "ditto failed creating #{archive_path}" unless success

        archive_path
      end

      def create_tar_gz
        require "rubygems/package"

        archive_path = "#{source_path}.tar.gz"
        FileUtils.rm_f(archive_path)

        File.open(archive_path, "wb") do |file|
          Zlib::GzipWriter.wrap(file) do |gzip|
            Gem::Package::TarWriter.new(gzip) do |tar|
              write_directory_to_tar(tar:, dir: source_path, prefix: source_name)
            end
          end
        end

        archive_path
      end

      def create_zip
        archive_path = "#{source_path}.zip"
        FileUtils.rm_f(archive_path)

        Zip::File.open(archive_path, create: true) do |zipfile|
          collect_files.each do |file_path|
            relative = "#{source_name}/#{file_path.delete_prefix("#{source_path}/")}"
            zipfile.add(relative, file_path)
          end
        end

        archive_path
      end

      private

      attr_reader :source_path

      def source_name
        File.basename(source_path)
      end

      def collect_files
        Dir.glob(File.join(source_path, "**", "*"))
          .reject { |f| File.directory?(f) }
          .sort
      end

      def write_directory_to_tar(tar:, dir:, prefix:)
        Dir.glob(File.join(dir, "**", "*"), File::FNM_DOTMATCH).sort.each do |entry|
          next if File.basename(entry).match?(/\A\.\.?\z/)

          relative = "#{prefix}/#{entry.delete_prefix("#{dir}/")}"
          stat = File.stat(entry)

          next if stat.directory?

          tar.add_file_simple(relative, stat.mode, stat.size) do |io|
            File.open(entry, "rb") { |f| io.write(f.read) }
          end
        end
      end
    end
  end
end
