# Shared context for web integration tests.
# Builds the web project once, serves via Capybara, cleans up after.
#
# Usage:
#   RSpec.describe "My web test", :web do
#     include_context "with web game", project: File.expand_path("../../examples/demo", __dir__)
#     include WebTestHelpers
#   end

RSpec.shared_context "with web game" do |project:|
  before(:all) do
    require_relative "web_test_helpers"
    require_relative "dama_web_app"

    @web_project_root = project
    builder = Dama::WebBuilder.new(project_root: project)
    builder.build
    dist = File.join(project, "dist")
    Capybara.app = DamaWebApp.new(dist_dir: dist)
  end

  # dist/ is gitignored. Don't clean up — it's reused across test runs
  # and deleting it would break Capybara's Rack app mid-suite.
end
