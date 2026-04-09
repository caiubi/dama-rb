module Overcommit
  module Hook
    module CommitMsg
      # Validates that the commit message follows the Conventional Commits specification.
      # Format: type(scope): description
      #   - type is required (feat, fix, docs, etc.)
      #   - scope is optional
      #   - ! before : denotes a breaking change
      class ConventionalCommit < Base
        TYPES = %w[feat fix docs style refactor perf test build ci chore revert].freeze
        PATTERN = /\A(?:#{TYPES.join("|")})(?:\([^)]+\))?!?:\s.+\z/

        def run
          first_line = commit_message_lines.first

          return :pass if merge_commit?(first_line:)

          return :pass if first_line&.match?(PATTERN)

          [:fail, error_message]
        end

        private

        def merge_commit?(first_line:)
          first_line&.start_with?("Merge ")
        end

        def error_message
          <<~MSG
            Commit message must follow Conventional Commits format:

              type(scope): description

            Valid types: #{TYPES.join(", ")}
            Examples:
              feat(engine): add sprite rotation support
              fix: resolve memory leak in scene graph
              docs: update installation instructions
          MSG
        end
      end
    end
  end
end
