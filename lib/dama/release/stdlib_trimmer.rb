require "fileutils"

module Dama
  module Release
    # Removes stdlib modules and native extensions that games don't
    # need at runtime, reducing the bundled Ruby size by ~60%.
    # Uses an exclusion-based approach (safer than a whitelist) so
    # new stdlib additions aren't accidentally removed.
    class StdlibTrimmer
      # Pure-Ruby stdlib directories that are build tools, documentation
      # generators, or parser infrastructure -- never needed at game runtime.
      # Networking (net/, openssl/) and other libraries are intentionally
      # kept since games may use them for multiplayer, asset loading, etc.
      EXCLUDED_DIRS = %w[
        bundler
        did_you_mean
        error_highlight
        irb
        prism
        racc
        rbs
        rdoc
        reline
        ripper
        ruby_vm
        rubygems
        syntax_suggest
      ].freeze

      # Top-level .rb files that correspond to excluded directories
      # or standalone modules not needed at runtime.
      EXCLUDED_FILES = %w[
        bundler.rb
        bundled_gems.rb
        debug.rb
        did_you_mean.rb
        error_highlight.rb
        irb.rb
        mkmf.rb
        prism.rb
        rdoc.rb
        reline.rb
        ripper.rb
        rubygems.rb
        syntax_suggest.rb
      ].freeze

      # Native extensions for build/dev-only tools.
      EXCLUDED_NATIVE_EXTENSIONS = %w[
        ripper
      ].freeze

      def initialize(stdlib_dir:, arch_dir:)
        @stdlib_dir = stdlib_dir
        @arch_dir = arch_dir
      end

      def trim
        remove_excluded_dirs
        remove_excluded_files
        remove_excluded_native_extensions
        remove_debug_symbols
        trim_encodings
      end

      private

      attr_reader :stdlib_dir, :arch_dir

      def remove_excluded_dirs
        EXCLUDED_DIRS.each do |dir|
          FileUtils.rm_rf(File.join(stdlib_dir, dir))
        end
      end

      def remove_excluded_files
        EXCLUDED_FILES.each do |file|
          FileUtils.rm_f(File.join(stdlib_dir, file))
        end
      end

      def remove_excluded_native_extensions
        EXCLUDED_NATIVE_EXTENSIONS.each do |name|
          Dir.glob(File.join(arch_dir, "#{name}.*")).each { |f| FileUtils.rm_rf(f) }
          FileUtils.rm_rf(File.join(arch_dir, name))
        end
      end

      # Debug symbol directories (.dSYM) are macOS build artifacts
      # that add megabytes without any runtime benefit.
      def remove_debug_symbols
        Dir.glob(File.join(arch_dir, "**", "*.dSYM")).each do |dsym|
          FileUtils.rm_rf(dsym)
        end
      end

      # Ruby's encoding directory contains bundles for dozens of legacy
      # character encodings. Games only need the encoding database
      # (encdb) and transcoding database (transdb) that Ruby loads at boot,
      # plus UTF-8 which is already compiled into the Ruby binary.
      def trim_encodings
        enc_dir = File.join(arch_dir, "enc")
        return unless File.directory?(enc_dir)

        keep_encoding_essentials(enc_dir:)
      end

      def keep_encoding_essentials(enc_dir:)
        trans_dir = File.join(enc_dir, "trans")

        essential_files = [
          File.join(enc_dir, "encdb.bundle"),
          File.join(enc_dir, "encdb.so"),
        ].select { |f| File.exist?(f) }

        essential_trans = [
          File.join(trans_dir, "transdb.bundle"),
          File.join(trans_dir, "transdb.so"),
        ].select { |f| File.exist?(f) }

        # Remove everything except the essential encoding files
        non_essential_entries(enc_dir:, essential_files:).each { |e| FileUtils.rm_rf(e) }
        non_essential_entries(enc_dir: trans_dir, essential_files: essential_trans).each { |e| FileUtils.rm_rf(e) }
      end

      def non_essential_entries(enc_dir:, essential_files:)
        Dir.children(enc_dir)
          .map { |child| File.join(enc_dir, child) }
          .reject { |path| essential_files.include?(path) || File.directory?(path) }
      end
    end
  end
end
