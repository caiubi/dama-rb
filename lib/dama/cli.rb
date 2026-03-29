module Dama
  # Command-line interface for the dama gem.
  # Dispatches subcommands to their handlers via Hash lookup.
  class Cli
    def self.run(args:)
      command_name = args.first
      COMMANDS.fetch(command_name, DEFAULT).call
    end

    COMMANDS = {
      "new" => -> { Cli::NewProject.run },
    }.freeze

    DEFAULT = -> { Dama.boot(root: Dir.pwd) }
  end
end
