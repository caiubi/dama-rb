# Shared context that initializes the native backend in headless mode.
# Used by specs that need real GPU rendering without a window.
RSpec.shared_context "with headless backend" do
  let(:configuration) { Dama::Configuration.new(width: 64, height: 64, headless: true) }
  let(:backend) { Dama::Backend::Native.new }

  before do
    backend.initialize_engine(configuration:)
  end

  after do
    backend.shutdown
  end
end
