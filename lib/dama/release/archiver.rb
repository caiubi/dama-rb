require "fileutils"
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

        ZipWriter.new(archive_path:, source_path:, prefix: source_name).write

        archive_path
      end

      private

      attr_reader :source_path

      def source_name
        File.basename(source_path)
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

      # Minimal ZIP archive writer using Ruby's Zlib for deflation.
      # Supports only the features needed for game release archives:
      # deflate-compressed regular files with relative paths.
      class ZipWriter
        def initialize(archive_path:, source_path:, prefix:)
          @archive_path = archive_path
          @source_path = source_path
          @prefix = prefix
        end

        def write
          entries = []

          File.open(archive_path, "wb") do |io|
            collect_files.each do |file_path|
              entries << write_local_entry(io:, file_path:)
            end

            central_dir_offset = io.pos
            entries.each { |entry| write_central_entry(io:, entry:) }
            write_end_of_central_dir(io:, entries:, central_dir_offset:)
          end
        end

        private

        attr_reader :archive_path, :source_path, :prefix

        def collect_files
          Dir.glob(File.join(source_path, "**", "*"))
            .reject { |f| File.directory?(f) }
            .sort
        end

        def write_local_entry(io:, file_path:)
          relative = "#{prefix}/#{file_path.delete_prefix("#{source_path}/")}"
          data = File.binread(file_path)
          crc = Zlib.crc32(data)
          compressed = Zlib::Deflate.deflate(data)

          header_offset = io.pos
          io.write(local_file_header(name: relative, compressed_size: compressed.bytesize,
                                     uncompressed_size: data.bytesize, crc:))
          io.write(compressed)

          { name: relative, compressed_size: compressed.bytesize,
            uncompressed_size: data.bytesize, crc:, header_offset: }
        end

        def write_central_entry(io:, entry:)
          io.write(central_directory_header(**entry))
        end

        def write_end_of_central_dir(io:, entries:, central_dir_offset:)
          central_dir_size = io.pos - central_dir_offset
          io.write(end_of_central_directory(
                     entry_count: entries.size,
                     central_dir_size:,
                     central_dir_offset:,
                   ))
        end

        # ZIP format structures (PKZIP APPNOTE 4.3.7, 4.3.12, 4.3.16)

        def local_file_header(name:, compressed_size:, uncompressed_size:, crc:)
          [
            0x04034b50,        # local file header signature
            20,                # version needed (2.0)
            0,                 # general purpose bit flag
            8,                 # compression method (deflate)
            0, 0,              # last mod time, date
            crc,
            compressed_size,
            uncompressed_size,
            name.bytesize,     # file name length
            0 # extra field length
          ].pack("VvvvvvVVVvv") + name.b
        end

        def central_directory_header(name:, compressed_size:, uncompressed_size:, crc:, header_offset:)
          [
            0x02014b50,        # central directory header signature
            20,                # version made by
            20,                # version needed
            0, 8,              # flags, compression
            0, 0,              # time, date
            crc,
            compressed_size,
            uncompressed_size,
            name.bytesize,     # file name length
            0, 0, 0, 0, # extra, comment, disk, internal attrs
            0,                 # external attrs
            header_offset
          ].pack("VvvvvvvVVVvvvvvVV") + name.b
        end

        def end_of_central_directory(entry_count:, central_dir_size:, central_dir_offset:)
          [
            0x06054b50,        # end of central directory signature
            0, 0,              # disk numbers
            entry_count,
            entry_count,
            central_dir_size,
            central_dir_offset,
            0 # comment length
          ].pack("VvvvvVVv")
        end
      end
    end
  end
end
