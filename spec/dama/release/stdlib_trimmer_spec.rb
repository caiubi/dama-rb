require "spec_helper"
require "tmpdir"

RSpec.describe Dama::Release::StdlibTrimmer do
  describe "#trim" do
    def create_stdlib(dir:)
      stdlib_dir = File.join(dir, "stdlib")
      arch_dir = File.join(stdlib_dir, "arm64-darwin25")
      FileUtils.mkdir_p(arch_dir)

      populate_excluded_entries(stdlib_dir:)
      populate_kept_entries(stdlib_dir:)
      populate_native_extensions(arch_dir:)
      populate_encodings(arch_dir:)

      { stdlib_dir:, arch_dir: }
    end

    def populate_excluded_entries(stdlib_dir:)
      described_class::EXCLUDED_DIRS.each do |excluded|
        FileUtils.mkdir_p(File.join(stdlib_dir, excluded))
        File.write(File.join(stdlib_dir, excluded, "main.rb"), "# #{excluded}")
      end

      described_class::EXCLUDED_FILES.each do |excluded|
        File.write(File.join(stdlib_dir, excluded), "# #{excluded}")
      end
    end

    def populate_kept_entries(stdlib_dir:)
      FileUtils.mkdir_p(File.join(stdlib_dir, "json"))
      File.write(File.join(stdlib_dir, "json", "common.rb"), "# json")
      File.write(File.join(stdlib_dir, "set.rb"), "# set")
      File.write(File.join(stdlib_dir, "pathname.rb"), "# pathname")
    end

    def populate_native_extensions(arch_dir:)
      %w[monitor pathname stringio openssl socket].each { |n| File.write(File.join(arch_dir, "#{n}.bundle"), "keep") }
      %w[ripper].each { |n| File.write(File.join(arch_dir, "#{n}.bundle"), "remove") }
      FileUtils.mkdir_p(File.join(arch_dir, "monitor.bundle.dSYM", "Contents"))
      FileUtils.mkdir_p(File.join(arch_dir, "openssl.bundle.dSYM", "Contents"))
    end

    def populate_encodings(arch_dir:)
      enc_dir = File.join(arch_dir, "enc")
      trans_dir = File.join(enc_dir, "trans")
      FileUtils.mkdir_p(trans_dir)
      File.write(File.join(enc_dir, "encdb.bundle"), "essential")
      %w[utf_8 iso_8859_1 shift_jis].each { |n| File.write(File.join(enc_dir, "#{n}.bundle"), "x") }
      File.write(File.join(trans_dir, "transdb.bundle"), "essential")
      %w[utf_16_32 japanese].each { |n| File.write(File.join(trans_dir, "#{n}.bundle"), "x") }
    end

    it "removes excluded pure-Ruby directories" do
      Dir.mktmpdir do |dir|
        paths = create_stdlib(dir:)

        described_class.new(**paths).trim

        described_class::EXCLUDED_DIRS.each do |excluded|
          expect(File.exist?(File.join(paths.fetch(:stdlib_dir), excluded))).to be(false)
        end
      end
    end

    it "removes excluded pure-Ruby files" do
      Dir.mktmpdir do |dir|
        paths = create_stdlib(dir:)

        described_class.new(**paths).trim

        described_class::EXCLUDED_FILES.each do |excluded|
          expect(File.exist?(File.join(paths.fetch(:stdlib_dir), excluded))).to be(false)
        end
      end
    end

    it "keeps non-excluded stdlib dirs and files" do
      Dir.mktmpdir do |dir|
        paths = create_stdlib(dir:)

        described_class.new(**paths).trim

        expect(File.exist?(File.join(paths.fetch(:stdlib_dir), "json", "common.rb"))).to be(true)
        expect(File.exist?(File.join(paths.fetch(:stdlib_dir), "set.rb"))).to be(true)
        expect(File.exist?(File.join(paths.fetch(:stdlib_dir), "pathname.rb"))).to be(true)
      end
    end

    it "removes excluded native extensions" do
      Dir.mktmpdir do |dir|
        paths = create_stdlib(dir:)

        described_class.new(**paths).trim

        arch = paths.fetch(:arch_dir)
        expect(File.exist?(File.join(arch, "ripper.bundle"))).to be(false)
      end
    end

    it "keeps native extensions that games may need" do
      Dir.mktmpdir do |dir|
        paths = create_stdlib(dir:)

        described_class.new(**paths).trim

        arch = paths.fetch(:arch_dir)
        expect(File.exist?(File.join(arch, "monitor.bundle"))).to be(true)
        expect(File.exist?(File.join(arch, "pathname.bundle"))).to be(true)
        expect(File.exist?(File.join(arch, "stringio.bundle"))).to be(true)
        expect(File.exist?(File.join(arch, "openssl.bundle"))).to be(true)
        expect(File.exist?(File.join(arch, "socket.bundle"))).to be(true)
      end
    end

    it "removes all dSYM debug symbol directories" do
      Dir.mktmpdir do |dir|
        paths = create_stdlib(dir:)

        described_class.new(**paths).trim

        dsyms = Dir.glob(File.join(paths.fetch(:arch_dir), "**", "*.dSYM"))
        expect(dsyms).to be_empty
      end
    end

    it "keeps only encdb and transdb in the encoding directory" do
      Dir.mktmpdir do |dir|
        paths = create_stdlib(dir:)

        described_class.new(**paths).trim

        enc_dir = File.join(paths.fetch(:arch_dir), "enc")
        trans_dir = File.join(enc_dir, "trans")

        expect(File.exist?(File.join(enc_dir, "encdb.bundle"))).to be(true)
        expect(File.exist?(File.join(trans_dir, "transdb.bundle"))).to be(true)

        expect(File.exist?(File.join(enc_dir, "utf_8.bundle"))).to be(false)
        expect(File.exist?(File.join(enc_dir, "iso_8859_1.bundle"))).to be(false)
        expect(File.exist?(File.join(enc_dir, "shift_jis.bundle"))).to be(false)
        expect(File.exist?(File.join(trans_dir, "utf_16_32.bundle"))).to be(false)
        expect(File.exist?(File.join(trans_dir, "japanese.bundle"))).to be(false)
      end
    end

    it "handles missing encoding directory gracefully" do
      Dir.mktmpdir do |dir|
        stdlib_dir = File.join(dir, "stdlib")
        arch_dir = File.join(stdlib_dir, "arm64-darwin25")
        FileUtils.mkdir_p(arch_dir)

        expect { described_class.new(stdlib_dir:, arch_dir:).trim }.not_to raise_error
      end
    end
  end
end
