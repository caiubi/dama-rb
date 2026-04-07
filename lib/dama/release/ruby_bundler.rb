require "bundler"
require "fileutils"
require "rbconfig"

module Dama
  module Release
    # Copies the Ruby runtime and gem dependencies into a release directory.
    # Creates a self-contained Ruby environment so the packaged game
    # can run without a system Ruby installation.
    class RubyBundler
      def initialize(destination:, project_root:)
        @destination = destination
        @project_root = project_root
      end

      def bundle
        copy_ruby_runtime
        install_gems
        ruby_destination
      end

      private

      attr_reader :destination, :project_root

      def ruby_destination
        File.join(destination, "ruby")
      end

      def copy_ruby_runtime
        ruby_binary = RbConfig.ruby
        dest_bindir = File.join(ruby_destination, "bin")

        FileUtils.mkdir_p(dest_bindir)
        FileUtils.cp(ruby_binary, File.join(dest_bindir, File.basename(ruby_binary)))

        copy_shared_library
        copy_ruby_stdlib
      end

      # Copies the Ruby shared library (e.g. libruby.3.4.dylib) into
      # the bundle so the binary doesn't depend on the build machine's paths.
      def copy_shared_library
        shared_lib = RbConfig::CONFIG.fetch("LIBRUBY_SO")
        return if shared_lib.empty?

        source = File.join(RbConfig::CONFIG.fetch("libdir"), shared_lib)
        return unless File.exist?(source)

        dest_libdir = File.join(ruby_destination, "lib")
        FileUtils.mkdir_p(dest_libdir)
        FileUtils.cp(source, dest_libdir)
      end

      def copy_ruby_stdlib
        rubylibdir = RbConfig::CONFIG.fetch("rubylibdir")
        dest_libdir = File.join(ruby_destination, "lib", "ruby", RbConfig::CONFIG.fetch("ruby_version"))
        FileUtils.mkdir_p(dest_libdir)
        FileUtils.cp_r("#{rubylibdir}/.", dest_libdir)

        archdir = RbConfig::CONFIG.fetch("archdir")
        dest_archdir = File.join(dest_libdir, RbConfig::CONFIG.fetch("arch"))
        FileUtils.mkdir_p(dest_archdir)
        FileUtils.cp_r("#{archdir}/.", dest_archdir)
      end

      # Runs bundle install using the project's original Gemfile so that
      # relative path: references (e.g. path: "../..") resolve correctly
      # against the project root, not the release directory.
      # Uses env vars instead of CLI flags to avoid writing .bundle/config
      # into the project directory. The --standalone flag generates a
      # bundler/setup.rb that sets up load paths without Bundler at runtime.
      def install_gems
        vendor_dir = File.join(destination, "vendor", "bundle")
        FileUtils.mkdir_p(vendor_dir)

        gemfile = File.join(project_root, "Gemfile")
        return unless File.exist?(gemfile)

        Bundler.with_unbundled_env do
          env = {
            "BUNDLE_PATH" => vendor_dir,
            "BUNDLE_GEMFILE" => gemfile,
          }
          success = system(env, "bundle", "install", "--standalone")
          raise "Gem bundling failed" unless success
        end

        embed_path_gems(vendor_dir:, gemfile:)
      end

      # Bundler's --standalone mode generates relative paths for path: gems
      # (e.g. path: "../..") that point back to the build machine's source tree.
      # For a portable app bundle, we copy each path gem's lib/ into the vendor
      # directory and rewrite setup.rb so it references the local copy.
      def embed_path_gems(vendor_dir:, gemfile:)
        setup_rb = File.join(vendor_dir, "bundler", "setup.rb")
        return unless File.exist?(setup_rb)

        gems = path_gem_lines(gemfile:)
        return if gems.empty?

        source_to_name = copy_path_gems(gems:, vendor_dir:)
        rewrite_setup_rb(
          setup_rb:,
          bundler_dir: File.join(vendor_dir, "bundler"),
          source_to_name:,
        )
      end

      def copy_path_gems(gems:, vendor_dir:)
        gems.to_h do |gem_name, source_lib|
          embedded_lib = File.join(vendor_dir, "path_gems", gem_name, "lib")
          FileUtils.mkdir_p(embedded_lib)
          FileUtils.cp_r("#{source_lib}/.", embedded_lib)
          [source_lib, gem_name]
        end
      end

      # Rewrites path-gem entries in setup.rb to reference the embedded copies.
      # Identifies each line's target gem by resolving its relative path back to
      # an absolute path and matching against known source lib directories.
      # This handles multiple path gems correctly, unlike a generic regex gsub.
      def rewrite_setup_rb(setup_rb:, bundler_dir:, source_to_name:)
        content = File.readlines(setup_rb).map do |line|
          gem_name = match_path_gem(line:, bundler_dir:, source_to_name:)
          gem_name ? path_gem_load_line(gem_name:) : line
        end.join

        File.write(setup_rb, content)
      end

      # Matches any $:.unshift line that loads from a #{__dir__}-relative path.
      # The captured rel_path is resolved against the bundler directory to
      # determine which path gem (if any) this line references.
      SETUP_LOAD_PATTERN = %r{\A\$:\.\s*unshift\s+File\.expand_path\("\#\{__dir__\}/(?<rel_path>[^"]+)"\)\n?\z}

      def match_path_gem(line:, bundler_dir:, source_to_name:)
        match = line.match(SETUP_LOAD_PATTERN)
        return unless match

        resolved = File.expand_path(match[:rel_path], bundler_dir)
        source_to_name[resolved]
      end

      def path_gem_load_line(gem_name:)
        "$:.unshift File.expand_path(\"\#{__dir__}/../path_gems/#{gem_name}/lib\")\n"
      end

      def path_gem_lines(gemfile:)
        File.readlines(gemfile).filter_map do |line|
          match = line.match(/gem\s+"(?<name>[^"]+)".*path:\s*"(?<path>[^"]+)"/)
          next unless match

          gem_path = File.expand_path(match[:path], File.dirname(gemfile))
          [match[:name], File.join(gem_path, "lib")]
        end
      end
    end
  end
end
