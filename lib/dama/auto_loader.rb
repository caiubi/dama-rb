module Dama
  # Discovers and loads all Ruby files in a game project directory.
  # Handles dependency ordering automatically by retrying files
  # that fail due to undefined constants.
  class AutoLoader
    MAX_PASSES = 10

    def initialize(game_dir:)
      @game_dir = game_dir
    end

    def load_all
      files = discover_files
      load_with_retries(files:)
    end

    private

    attr_reader :game_dir

    def discover_files
      Dir[File.join(game_dir, "**", "*.rb")]
    end

    # Repeatedly attempt to load files, retrying those that fail
    # with NameError (undefined constant — dependency not yet loaded).
    # Stops when all files are loaded or no progress is made.
    def load_with_retries(files:)
      remaining = files.dup

      MAX_PASSES.times do
        failed = []

        remaining.each do |file|
          require file
        rescue NameError
          failed << file
        end

        return if failed.empty?

        # No progress — the remaining files have unresolvable errors.
        raise_load_error(failed:) if failed.size == remaining.size

        remaining = failed
      end
    end

    def raise_load_error(failed:)
      # Try loading each failed file one more time to get the real error message.
      failed.each { |file| require file }
    end
  end
end
