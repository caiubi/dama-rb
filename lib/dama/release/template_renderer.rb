require "erb"

module Dama
  module Release
    # Renders ERB templates from the templates/ directory.
    # Separates template content (shell scripts, XML plists) from
    # Ruby packaging logic so each can be edited independently.
    class TemplateRenderer
      TEMPLATES_DIR = File.expand_path("templates", __dir__)

      def initialize(template_name:, variables:)
        @template_name = template_name
        @variables = variables
      end

      def render
        template = ERB.new(template_content, trim_mode: "-")
        template.result(template_binding)
      end

      private

      attr_reader :template_name, :variables

      def template_content
        File.read(File.join(TEMPLATES_DIR, template_name))
      end

      # Builds a clean binding where each variable key becomes
      # a local method, keeping templates simple and explicit.
      def template_binding
        namespace = Object.new
        variables.each do |key, value|
          namespace.define_singleton_method(key) { value }
        end
        namespace.instance_eval { binding }
      end
    end
  end
end
