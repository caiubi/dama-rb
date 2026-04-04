require "zeitwerk"

module Dama
  class << self
    def loader
      @loader ||= begin
        loader = Zeitwerk::Loader.for_gem
        loader.setup
        loader
      end
    end

    def root
      File.expand_path("..", __dir__)
    end

    # Boot a game project. Auto-loads game files, requires config,
    # and either starts the native game or builds/serves the web version.
    #
    # @param root [String] Path to the game project root (contains game/, config.rb, bin/)
    def boot(root:)
      game_dir = File.join(root, "game")
      config_file = File.join(root, "config.rb")

      AutoLoader.new(game_dir:).load_all
      require config_file

      web_requested = ARGV[0] == "web"
      BOOT_ACTIONS.fetch(web_requested).call(root)
    end

    BOOT_ACTIONS = {
      true => lambda { |root|
        puts "Building and serving web version..."
        WebBuilder.build_and_serve(project_root: root, port: 8080)
      },
      false => ->(_root) { GAME.start },
    }.freeze
  end
end

Dama.loader
