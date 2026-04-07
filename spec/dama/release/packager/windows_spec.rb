require "spec_helper"
require "tmpdir"

RSpec.describe Dama::Release::Packager::Windows do
  describe "#package" do
    let(:lib_extension) { "dll" }
    let(:icon_extension) { "ico" }
    let(:release_dir_for) { ->(dir, name) { File.join(dir, "release", name) } }

    it_behaves_like "a native packager"

    include_context "with packager stubs"

    it "creates a .bat launcher script" do
      Dir.mktmpdir do |dir|
        create_game_project(dir)
        stub_builds(project_root: dir, extension: lib_extension)

        described_class.new(project_root: dir).package

        bat_path = File.join(dir, "release", "Test Game", "Test Game.bat")
        expect(File.exist?(bat_path)).to be(true)
        expect(File.read(bat_path)).to include("DAMA_NATIVE_LIB")
        expect(File.read(bat_path)).to include("fake_lib.dll")
      end
    end

    it "sets RUBYLIB in the launcher to point to the bundled stdlib" do
      Dir.mktmpdir do |dir|
        create_game_project(dir)
        stub_builds(project_root: dir, extension: lib_extension)

        described_class.new(project_root: dir).package

        bat_path = File.join(dir, "release", "Test Game", "Test Game.bat")
        content = File.read(bat_path)
        ruby_version = RbConfig::CONFIG.fetch("ruby_version")
        ruby_arch = RbConfig::CONFIG.fetch("arch")
        stdlib = "%DIR%\\ruby\\lib\\ruby\\#{ruby_version}"
        expect(content).to include("RUBYLIB=#{stdlib};#{stdlib}\\#{ruby_arch}")
      end
    end
  end
end
