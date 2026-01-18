module Dama
  class Registry
    # Resolves symbol/string names to registered classes.
    # Classes are registered by category (:component, :node, :scene)
    # and looked up via a snake_case key derived from the class name.
    class ClassResolver
      CATEGORIES = %i[component node scene].freeze

      def initialize
        @registrations = CATEGORIES.to_h { |cat| [cat, {}] }
      end

      def register(klass:, category:)
        key = derive_key(klass:)
        registrations.fetch(category)[key] = klass
      end

      def resolve(name:, category:)
        key = normalize_name(name:)
        registrations.fetch(category).fetch(key)
      end

      private

      attr_reader :registrations

      # Derives a snake_case symbol key from a class name.
      # Only uses the last segment (after ::) to avoid namespace prefixes.
      # Uses a regex with named groups to split CamelCase boundaries.
      CAMEL_BOUNDARY = /(?<upper>[A-Z]+)(?<next_upper>[A-Z][a-z])/
      CAMEL_LOWER = /(?<lower>[a-z\d])(?<upper>[A-Z])/

      def derive_key(klass:)
        # Extract the class basename (last segment after ::).
        basename = klass.name&.match(/(?<basename>[^:]+)\z/)&.[](:basename) || klass.to_s
        basename
          .gsub(CAMEL_BOUNDARY, '\k<upper>_\k<next_upper>')
          .gsub(CAMEL_LOWER, '\k<lower>_\k<upper>')
          .downcase
          .to_sym
      end

      def normalize_name(name:)
        name.to_s.downcase.to_sym
      end
    end
  end
end
