module Dama
  # Command-line interface for the dama gem.
  # Dispatches subcommands to their handlers via Hash lookup.
  #
  # Project binstubs pass root: so the CLI knows the project
  # directory regardless of the caller's working directory.
  # The gem-installed exe/dama omits root:, defaulting to Dir.pwd.
  class Cli
    def self.run(args:, root: Dir.pwd)
      command_name = args.first
      remaining_args = args.drop(1)
      COMMANDS.fetch(command_name, DEFAULT).call(remaining_args, root)
    end

    COMMANDS = {
      "new" => ->(_args, _root) { Cli::NewProject.run },
      "release" => ->(args, root) { Cli::Release.run(args:, root:) },
    }.freeze

    DEFAULT = ->(_args, root) { Dama.boot(root:) }
  end
end
