require "spec_helper"
require "tmpdir"

RSpec.describe Dama::Release::IconProvider do
  describe "#icon_path" do
    it "returns user icon from assets/ when it exists for macOS" do
      Dir.mktmpdir do |dir|
        assets_dir = File.join(dir, "assets")
        FileUtils.mkdir_p(assets_dir)
        user_icon = File.join(assets_dir, "icon.icns")
        File.write(user_icon, "fake icns data")

        provider = described_class.new(project_root: dir, platform: :macos)

        expect(provider.icon_path).to eq(user_icon)
      end
    end

    it "returns user icon from assets/ when it exists for linux" do
      Dir.mktmpdir do |dir|
        assets_dir = File.join(dir, "assets")
        FileUtils.mkdir_p(assets_dir)
        user_icon = File.join(assets_dir, "icon.png")
        File.write(user_icon, "fake png data")

        provider = described_class.new(project_root: dir, platform: :linux)

        expect(provider.icon_path).to eq(user_icon)
      end
    end

    it "returns user icon from assets/ when it exists for windows" do
      Dir.mktmpdir do |dir|
        assets_dir = File.join(dir, "assets")
        FileUtils.mkdir_p(assets_dir)
        user_icon = File.join(assets_dir, "icon.ico")
        File.write(user_icon, "fake ico data")

        provider = described_class.new(project_root: dir, platform: :windows)

        expect(provider.icon_path).to eq(user_icon)
      end
    end

    it "falls back to gem default icon when user icon does not exist" do
      Dir.mktmpdir do |dir|
        provider = described_class.new(project_root: dir, platform: :macos)

        expect(provider.icon_path).to eq(described_class::DEFAULT_ICONS_PATH.call("icns"))
      end
    end

    it "uses the correct extension for each platform" do
      Dir.mktmpdir do |dir|
        macos_provider = described_class.new(project_root: dir, platform: :macos)
        linux_provider = described_class.new(project_root: dir, platform: :linux)
        windows_provider = described_class.new(project_root: dir, platform: :windows)

        expect(macos_provider.icon_path).to end_with(".icns")
        expect(linux_provider.icon_path).to end_with(".png")
        expect(windows_provider.icon_path).to end_with(".ico")
      end
    end
  end
end
