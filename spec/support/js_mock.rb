# Defines the JS mock module for testing Backend::Web.
# NOT auto-loaded — only used via RSpec shared context.

RSpec.shared_context "with JS mock" do
  before do
    # rubocop:disable Style/BlockDelimiters
    stub_const("JS", Module.new {
      class JsValue
        def initialize(value = nil)
          @value = value
          @properties = {}
          @calls = []
        end

        attr_reader :calls

        def [](key)
          @properties[key] ||= JsValue.new
        end

        def []=(key, val)
          @properties[key] = val.is_a?(JsValue) ? val : JsValue.new(val)
        end

        def call(method_name, *args)
          @calls << [method_name, *args]
          JsValue.new("false")
        end

        def to_f = @value.to_f
        def to_i = @value.to_i
        def to_s = @value.to_s
      end

      @global = JsValue.new

      module_function

      def global = @global # rubocop:disable Style/TrivialAccessors
      def eval(_code) = JsValue.new
      def reset! = @global = JsValue.new
    })
    # rubocop:enable Style/BlockDelimiters
  end
end
