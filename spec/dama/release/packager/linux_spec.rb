require "spec_helper"
require "tmpdir"

RSpec.describe Dama::Release::Packager::Linux do
  describe "#package" do
    let(:lib_extension) { "so" }
    let(:icon_extension) { "png" }
    let(:release_dir_for) { ->(dir, name) { File.join(dir, "release", name) } }

    it_behaves_like "a native packager"

    include_context "with packager stubs"

    it "creates an executable launcher script" do
      Dir.mktmpdir do |dir|
        create_game_project(dir)
        stub_builds(project_root: dir, extension: lib_extension)

        described_class.new(project_root: dir).package

        launcher = File.join(dir, "release", "Test Game", "test-game")
        expect(File.executable?(launcher)).to be(true)
        expect(File.read(launcher)).to include("DAMA_NATIVE_LIB")
        expect(File.read(launcher)).to include("fake_lib.so")
      end
    end

    it "sets RUBYLIB in the launcher to point to the bundled stdlib" do
      Dir.mktmpdir do |dir|
        create_game_project(dir)
        stub_builds(project_root: dir, extension: lib_extension)

        described_class.new(project_root: dir).package

        launcher = File.join(dir, "release", "Test Game", "test-game")
        content = File.read(launcher)
        ruby_version = RbConfig::CONFIG.fetch("ruby_version")
        ruby_arch = RbConfig::CONFIG.fetch("arch")
        stdlib = "$DIR/ruby/lib/ruby/#{ruby_version}"
        expect(content).to include("RUBYLIB=\"#{stdlib}:#{stdlib}/#{ruby_arch}\"")
      end
    end
  end
end
