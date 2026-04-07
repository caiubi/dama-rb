# Shared setup and examples for native platform packager specs.
# Each packager (macOS, Linux, Windows) shares the same project
# scaffolding and build-tool stubbing; only the output structure differs.
#
# Including specs must define these lets:
#   let(:lib_extension)    { "dylib" }
#   let(:icon_extension)   { "icns" }
#   let(:release_dir_for)  { ->(dir, name) { File.join(dir, "release", name) } }
RSpec.shared_context "with packager stubs" do
  def create_game_project(dir)
    FileUtils.mkdir_p(File.join(dir, "game", "scenes"))
    File.write(File.join(dir, "game", "scenes", "main.rb"), "class MainScene; end")

    File.write(File.join(dir, "config.rb"), <<~RUBY)
      GAME = Dama::Game.new do
        settings resolution: [800, 600], title: "Test Game"
        start_scene MainScene
      end
    RUBY

    FileUtils.mkdir_p(File.join(dir, "assets"))
    File.write(File.join(dir, "assets", "sprite.png"), "fake png")
  end

  def stub_builds(project_root:, extension:)
    native_lib = File.join(project_root, "fake_lib.#{extension}")
    File.write(native_lib, "fake #{extension}")

    native_builder = instance_double(Dama::Release::NativeBuilder, build: native_lib)
    allow(Dama::Release::NativeBuilder).to receive(:new).and_return(native_builder)

    ruby_bundler = instance_double(Dama::Release::RubyBundler, bundle: File.join(project_root, "release", "ruby"))
    allow(Dama::Release::RubyBundler).to receive(:new).and_return(ruby_bundler)

    dylib_relinker = instance_double(Dama::Release::DylibRelinker, relink: nil)
    allow(Dama::Release::DylibRelinker).to receive(:new).and_return(dylib_relinker)

    archiver = instance_double(Dama::Release::Archiver,
                               create_macos_zip: "fake.zip",
                               create_tar_gz: "fake.tar.gz",
                               create_zip: "fake.zip")
    allow(Dama::Release::Archiver).to receive(:new).and_return(archiver)
  end
end

RSpec.shared_examples "a native packager" do
  include_context "with packager stubs"

  it "creates a release directory" do
    Dir.mktmpdir do |dir|
      create_game_project(dir)
      stub_builds(project_root: dir, extension: lib_extension)

      described_class.new(project_root: dir).package

      expect(File.directory?(release_dir_for.call(dir, "Test Game"))).to be(true)
    end
  end

  it "copies the native library and game files" do
    Dir.mktmpdir do |dir|
      create_game_project(dir)
      stub_builds(project_root: dir, extension: lib_extension)

      described_class.new(project_root: dir).package

      release_path = release_dir_for.call(dir, "Test Game")
      expect(File.exist?(File.join(release_path, "fake_lib.#{lib_extension}"))).to be(true)
      expect(File.exist?(File.join(release_path, "config.rb"))).to be(true)
      expect(File.exist?(File.join(release_path, "game", "scenes", "main.rb"))).to be(true)
      expect(File.exist?(File.join(release_path, "assets", "sprite.png"))).to be(true)
    end
  end

  it "handles a minimal project with no game/, assets/, or config.rb" do
    Dir.mktmpdir do |dir|
      stub_builds(project_root: dir, extension: lib_extension)

      described_class.new(project_root: dir).package

      release_path = release_dir_for.call(dir, File.basename(dir))
      expect(File.directory?(release_path)).to be(true)
      expect(Dir.children(release_path)).not_to include("game", "config.rb", "assets")
    end
  end

  it "skips icon copy when icon file does not exist" do
    Dir.mktmpdir do |dir|
      create_game_project(dir)
      stub_builds(project_root: dir, extension: lib_extension)

      icon_provider = instance_double(
        Dama::Release::IconProvider,
        icon_path: File.join(dir, "nonexistent.#{icon_extension}"),
      )
      allow(Dama::Release::IconProvider).to receive(:new).and_return(icon_provider)

      described_class.new(project_root: dir).package

      release_path = release_dir_for.call(dir, "Test Game")
      expect(Dir.children(release_path)).not_to include("icon.#{icon_extension}")
    end
  end
end
