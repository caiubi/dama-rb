require "spec_helper"
require "tmpdir"

RSpec.describe Dama::AutoLoader do
  describe "#load_all" do
    it "loads all Ruby files in the game directory" do
      Dir.mktmpdir do |dir|
        File.write(File.join(dir, "a.rb"), "$auto_loader_test_a = true")
        File.write(File.join(dir, "b.rb"), "$auto_loader_test_b = true")

        described_class.new(game_dir: dir).load_all

        expect($auto_loader_test_a).to be(true)
        expect($auto_loader_test_b).to be(true)
      end
    end

    it "handles dependency ordering via retry when dependent file loads first" do
      Dir.mktmpdir do |dir|
        # a_consumer.rb loads before z_provider.rb alphabetically,
        # so first pass fails on a_consumer, loads z_provider.
        # Second pass retries a_consumer — now it works.
        File.write(File.join(dir, "a_consumer.rb"), "$auto_loader_retry_result = AutoLoaderRetryProvider::VALUE")
        File.write(File.join(dir, "z_provider.rb"), "module AutoLoaderRetryProvider; VALUE = 99; end")

        described_class.new(game_dir: dir).load_all

        expect($auto_loader_retry_result).to eq(99)
      end
    end

    it "loads files in subdirectories" do
      Dir.mktmpdir do |dir|
        FileUtils.mkdir_p(File.join(dir, "sub"))
        File.write(File.join(dir, "sub", "nested.rb"), "$auto_loader_nested = true")

        described_class.new(game_dir: dir).load_all

        expect($auto_loader_nested).to be(true)
      end
    end

    it "raises the real error when files have unresolvable dependencies" do
      Dir.mktmpdir do |dir|
        File.write(File.join(dir, "broken.rb"), "NoSuchConstantEver123.call")

        expect do
          described_class.new(game_dir: dir).load_all
        end.to raise_error(NameError, /NoSuchConstantEver123/)
      end
    end

    it "handles an empty directory" do
      Dir.mktmpdir do |dir|
        expect { described_class.new(game_dir: dir).load_all }.not_to raise_error
      end
    end

    it "raises after MAX_PASSES when circular dependencies exist" do
      Dir.mktmpdir do |dir|
        # Two files that depend on each other's constants — neither can load.
        File.write(File.join(dir, "a.rb"), "CircularA123 = CircularB123")
        File.write(File.join(dir, "b.rb"), "CircularB123 = CircularA123")

        expect do
          described_class.new(game_dir: dir).load_all
        end.to raise_error(NameError)
      end
    end
  end
end
