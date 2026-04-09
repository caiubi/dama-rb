module Overcommit
  module Hook
    module PreCommit
      # Runs cargo clippy with deny-warnings on the Rust native extension.
      # Triggered only when Rust source files or Cargo manifests change.
      class Clippy < Base
        MANIFEST_PATH = File.join("ext", "dama_native", "Cargo.toml").freeze

        def run
          result = execute(
            [
              "cargo", "clippy",
              "--manifest-path", MANIFEST_PATH,
              "--all-targets",
              "--", "-D", "warnings"
            ],
          )
          return :pass if result.success?

          [:fail, result.stderr]
        end
      end
    end
  end
end
