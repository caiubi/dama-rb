require "fileutils"
require "tmpdir"

module Dama
  # Builds and serves the web version of a dama game.
  # Handles: Rust wasm compilation, wasm-bindgen, rbwasm build/pack,
  # static file copying, and WEBrick HTTP serving.
  class WebBuilder # rubocop:disable Metrics/ClassLength
    RUST_CRATE_PATH = File.expand_path("../../ext/dama_native", __dir__)
    WEB_ENTRY_PATH = File.expand_path("web/entry.rb", __dir__)
    WEB_STATIC_PATH = File.expand_path("web/static", __dir__)
    WASM_TARGET = "wasm32-unknown-unknown".freeze

    HOST_OS_TRIPLES = {
      "darwin" => "apple-darwin",
      "linux" => "unknown-linux-gnu",
      "mingw" => "pc-windows-msvc",
      "mswin" => "pc-windows-msvc",
    }.freeze

    def self.build_and_serve(project_root:, port: 8080)
      require "webrick"
      builder = new(project_root:)
      builder.build
      builder.serve(port:)
    end

    def initialize(project_root:)
      @project_root = project_root
      @dist_dir = File.join(project_root, "dist")
    end

    def build
      FileUtils.mkdir_p(dist_dir)
      FileUtils.mkdir_p(File.join(dist_dir, "pkg"))

      build_rust_wasm
      run_wasm_bindgen
      build_ruby_wasm
      copy_static_files

      puts "Build complete: #{dist_dir}"
    end

    def serve(port:)
      kill_existing_server(port:)

      puts "Serving at http://localhost:#{port}"
      puts "Press Ctrl+C to stop."

      server = WEBrick::HTTPServer.new(
        Port: port,
        DocumentRoot: dist_dir,
        Logger: WEBrick::Log.new($stdout, WEBrick::Log::WARN),
        AccessLog: [],
      )

      trap("INT") { server.shutdown }
      server.start
    end

    private

    attr_reader :project_root, :dist_dir

    PORT_LISTER_COMMANDS = {
      "mingw" => ->(port) { `netstat -ano | findstr :#{port}`.scan(/\s(\d+)\s*$/).flatten },
      "mswin" => ->(port) { `netstat -ano | findstr :#{port}`.scan(/\s(\d+)\s*$/).flatten },
    }.freeze

    DEFAULT_PORT_LISTER = ->(port) { `lsof -ti:#{port} 2>/dev/null`.strip.split("\n") }

    # Terminate any process already listening on the target port.
    def kill_existing_server(port:)
      validated_port = Integer(port)
      platform_key = PORT_LISTER_COMMANDS.keys.detect { |k| RUBY_PLATFORM.include?(k) }
      lister = PORT_LISTER_COMMANDS.fetch(platform_key, DEFAULT_PORT_LISTER)
      pids = lister.call(validated_port).reject(&:empty?)
      return if pids.empty?

      puts "Killing existing server on port #{validated_port}..."
      pids.each { |pid| Process.kill("TERM", Integer(pid)) }
    rescue Errno::ESRCH
      # Process already exited.
    end

    def build_rust_wasm
      puts "=== Building Rust renderer for wasm32 ==="
      run_command(
        "cargo build --release --target #{WASM_TARGET}",
        dir: RUST_CRATE_PATH,
        env: { "RUSTFLAGS" => "--cfg=web_sys_unstable_apis" },
      )
    end

    def run_wasm_bindgen
      puts "=== Generating JS glue ==="
      wasm_path = File.join(RUST_CRATE_PATH, "target", WASM_TARGET, "release", "dama_native.wasm")
      pkg_dir = File.join(dist_dir, "pkg")
      run_command("wasm-bindgen --target web --out-dir #{pkg_dir} #{wasm_path}")
    end

    def build_ruby_wasm
      puts "=== Building ruby.wasm + packing game code ==="

      Dir.mktmpdir do |pack_dir|
        generate_dama_core(output: File.join(pack_dir, "dama_core.rb"))
        FileUtils.cp(WEB_ENTRY_PATH, File.join(pack_dir, "app.rb"))

        game_dir = File.join(project_root, "game")
        FileUtils.cp_r(game_dir, File.join(pack_dir, "game")) if File.directory?(game_dir)

        config_file = File.join(project_root, "config.rb")
        FileUtils.cp(config_file, pack_dir) if File.exist?(config_file)

        assets_dir = File.join(project_root, "assets")
        FileUtils.cp_r(assets_dir, File.join(pack_dir, "assets")) if File.directory?(assets_dir)

        ruby_wasm = File.join(dist_dir, "ruby_base.wasm")
        game_wasm = File.join(dist_dir, "game.wasm")

        build_base_ruby_wasm(ruby_wasm) unless File.exist?(ruby_wasm)

        Bundler.with_unbundled_env do
          run_command("rbwasm pack #{ruby_wasm} --dir #{pack_dir}::/src -o #{game_wasm}")
        end
      end

      copy_ruby_wasm_js unless File.exist?(File.join(dist_dir, "ruby_wasm.js"))
    end

    def build_base_ruby_wasm(output_path)
      puts "  Downloading pre-built ruby.wasm via npm..."
      Dir.mktmpdir do |tmp|
        run_command("npm pack ruby-head-wasm-wasi", dir: tmp)
        tarball = Dir["#{tmp}/ruby-head-wasm-wasi-*.tgz"].first
        run_command("tar xf #{tarball}", dir: tmp)
        FileUtils.cp(File.join(tmp, "package", "dist", "ruby.wasm"), output_path)
        FileUtils.cp(
          File.join(tmp, "package", "dist", "browser.esm.js"),
          File.join(dist_dir, "ruby_wasm.js"),
        )
      end
    end

    def copy_ruby_wasm_js
      # Already copied during build_base_ruby_wasm.
    end

    def copy_static_files
      puts "=== Copying static files ==="
      Dir[File.join(WEB_STATIC_PATH, "*")].each do |f|
        FileUtils.cp(f, dist_dir)
      end
    end

    # Auto-generate dama_core.rb by concatenating all pure-Ruby engine files.
    # This replaces the manual bash script and ensures the web build always
    # has the latest engine code.
    CORE_FILES = %w[
      version configuration keys colors
      component/attribute_definition component/attribute_set component
      node/component_slot node/draw_context node
      scene_graph scene_graph/instance_node scene_graph/group_node
      scene_graph/tag_index scene_graph/class_index scene_graph/path_selector
      scene_graph/query scene_graph/tree
      registry/class_resolver registry
      scene/composer scene
      backend/base command_buffer
      geometry geometry/triangle geometry/rect geometry/circle geometry/sprite
      asset_cache input/keyboard_state input/mouse_state input
      camera audio event_bus sprite_sheet
      physics physics/collider physics/body physics/collision physics/world
      tween tween/easing tween/lerp tween/manager
      animation
      debug debug/frame_controller
      game/builder game
      backend/web
    ].freeze

    def generate_dama_core(output:)
      lib_dir = File.expand_path("../..", __dir__)

      File.open(output, "w") do |f|
        f.puts "# Auto-generated at build time from lib/dama/**/*.rb"
        f.puts "# DO NOT EDIT — changes will be overwritten by WebBuilder."
        f.puts ""
        f.puts "module Dama; def self.root = '/src'; end"
        f.puts ""

        CORE_FILES.each do |name|
          path = File.join(lib_dir, "lib", "dama", "#{name}.rb")
          next unless File.exist?(path)

          f.puts "\n# --- #{File.basename(path)} ---"
          f.puts File.read(path)
        end

        f.puts "\nmodule Dama; module Backend; def self.for = Backend::Web.new; end; end"
      end
    end

    def run_command(cmd, dir: nil, env: {})
      full_env = ENV.to_h.merge(env)
      full_env["PATH"] = rust_enhanced_path(full_env.fetch("PATH", ""))
      opts = dir ? { chdir: dir } : {}
      success = system(full_env, cmd, **opts)
      raise "Command failed: #{cmd}" unless success
    end

    def rust_enhanced_path(existing_path)
      home = Dir.home
      rust_dirs = [
        File.join(home, ".cargo", "bin"),
        File.join(home, ".rustup", "toolchains", "stable-#{rust_host_triple}", "bin"),
      ].select { |d| File.directory?(d) }

      (rust_dirs + existing_path.split(File::PATH_SEPARATOR)).join(File::PATH_SEPARATOR)
    end

    def rust_host_triple
      arch = RUBY_PLATFORM.include?("arm64") || RUBY_PLATFORM.include?("aarch64") ? "aarch64" : "x86_64"
      os_key = HOST_OS_TRIPLES.keys.detect { |k| RUBY_PLATFORM.include?(k) }
      "#{arch}-#{HOST_OS_TRIPLES.fetch(os_key, "unknown-linux-gnu")}"
    end
  end
end
