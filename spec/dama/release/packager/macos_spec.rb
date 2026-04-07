require "spec_helper"
require "tmpdir"

RSpec.describe Dama::Release::Packager::Macos do
  describe "#package" do
    let(:lib_extension) { "dylib" }
    let(:icon_extension) { "icns" }
    let(:release_dir_for) do
      ->(dir, name) { File.join(dir, "release", "#{name}.app", "Contents", "Resources") }
    end

    it_behaves_like "a native packager"

    include_context "with packager stubs"

    it "creates Contents/MacOS/ and Contents/Resources/ directories" do
      Dir.mktmpdir do |dir|
        create_game_project(dir)
        stub_builds(project_root: dir, extension: lib_extension)

        described_class.new(project_root: dir).package

        app_path = File.join(dir, "release", "Test Game.app")
        expect(File.directory?(File.join(app_path, "Contents", "MacOS"))).to be(true)
        expect(File.directory?(File.join(app_path, "Contents", "Resources"))).to be(true)
      end
    end

    it "writes Info.plist with game metadata" do
      Dir.mktmpdir do |dir|
        create_game_project(dir)
        stub_builds(project_root: dir, extension: lib_extension)

        described_class.new(project_root: dir).package

        plist = File.read(File.join(dir, "release", "Test Game.app", "Contents", "Info.plist"))
        expect(plist).to include("<string>Test Game</string>")
        expect(plist).to include("<string>launch</string>")
        expect(plist).to include("<string>icon</string>")
        expect(plist).to include("<string>APPL</string>")
      end
    end

    it "creates an executable launcher script" do
      Dir.mktmpdir do |dir|
        create_game_project(dir)
        stub_builds(project_root: dir, extension: lib_extension)

        described_class.new(project_root: dir).package

        launcher = File.join(dir, "release", "Test Game.app", "Contents", "MacOS", "launch")
        content = File.read(launcher)
        expect(File.executable?(launcher)).to be(true)
        expect(content).to include("DAMA_NATIVE_LIB")
        expect(content).to include("fake_lib.dylib")
      end
    end

    it "sets RUBYLIB in the launcher to point to the bundled stdlib" do
      Dir.mktmpdir do |dir|
        create_game_project(dir)
        stub_builds(project_root: dir, extension: lib_extension)

        described_class.new(project_root: dir).package

        launcher = File.join(dir, "release", "Test Game.app", "Contents", "MacOS", "launch")
        content = File.read(launcher)
        ruby_version = RbConfig::CONFIG.fetch("ruby_version")
        ruby_arch = RbConfig::CONFIG.fetch("arch")
        stdlib = "$DIR/ruby/lib/ruby/#{ruby_version}"
        expect(content).to include("RUBYLIB=\"#{stdlib}:#{stdlib}/#{ruby_arch}\"")
      end
    end

    it "escapes XML special characters in Info.plist title" do
      Dir.mktmpdir do |dir|
        FileUtils.mkdir_p(File.join(dir, "game", "scenes"))
        File.write(File.join(dir, "config.rb"), <<~RUBY)
          GAME = Dama::Game.new do
            settings resolution: [800, 600], title: "Dungeons & Dragons <2>"
            start_scene MainScene
          end
        RUBY
        stub_builds(project_root: dir, extension: lib_extension)

        described_class.new(project_root: dir).package

        plist = File.read(File.join(dir, "release", "Dungeons & Dragons 2.app", "Contents", "Info.plist"))
        expect(plist).to include("<string>Dungeons &amp; Dragons &lt;2&gt;</string>")
        expect(plist).not_to include("Dungeons & Dragons <2>")
      end
    end

    it "cleans previous .app before rebuilding" do
      Dir.mktmpdir do |dir|
        create_game_project(dir)
        stub_builds(project_root: dir, extension: lib_extension)

        app_path = File.join(dir, "release", "Test Game.app")
        FileUtils.mkdir_p(File.join(app_path, "Contents", "stale"))
        File.write(File.join(app_path, "Contents", "stale", "old.txt"), "stale")

        described_class.new(project_root: dir).package

        expect(File.exist?(File.join(app_path, "Contents", "stale", "old.txt"))).to be(false)
      end
    end

    it "relinks dynamic libraries after copying the ruby runtime" do
      Dir.mktmpdir do |dir|
        create_game_project(dir)
        stub_builds(project_root: dir, extension: lib_extension)

        described_class.new(project_root: dir).package

        expect(Dama::Release::DylibRelinker).to have_received(:new).with(
          binary_path: File.join(dir, "release", "ruby", "bin", RbConfig::CONFIG.fetch("ruby_install_name")),
          lib_destination: File.join(dir, "release", "ruby", "lib"),
        )
      end
    end
  end
end
