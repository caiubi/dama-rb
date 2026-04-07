module Dama
  module Release
    # Compiles the Rust native library in release mode.
    # Returns the path to the compiled shared library,
    # using the platform-appropriate extension from FfiBindings.
    class NativeBuilder
      RUST_CRATE_PATH = File.expand_path("../../../ext/dama_native", __dir__)

      def build
        puts "=== Building native library (release) ==="
        run_command("cargo build --release", dir: RUST_CRATE_PATH)
        library_path
      end

      def library_path
        platform_key = Backend::Native::FfiBindings::LIBRARY_EXTENSIONS.keys.detect do |k|
          RUBY_PLATFORM.include?(k)
        end
        extension = Backend::Native::FfiBindings::LIBRARY_EXTENSIONS.fetch(platform_key)
        File.join(RUST_CRATE_PATH, "target", "release", "libdama_native.#{extension}")
      end

      private

      def run_command(cmd, dir:)
        full_env = ENV.to_h
        full_env["PATH"] = rust_enhanced_path(full_env.fetch("PATH", ""))
        success = system(full_env, cmd, chdir: dir)
        raise "Command failed: #{cmd}" unless success
      end

      def rust_enhanced_path(existing_path)
        home = Dir.home
        rust_dirs = [
          File.join(home, ".cargo", "bin"),
        ].select { |d| File.directory?(d) }

        (rust_dirs + existing_path.split(File::PATH_SEPARATOR)).join(File::PATH_SEPARATOR)
      end
    end
  end
end
