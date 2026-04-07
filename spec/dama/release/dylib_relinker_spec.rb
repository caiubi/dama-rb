require "spec_helper"
require "tmpdir"

RSpec.describe Dama::Release::DylibRelinker do
  describe "#relink" do
    def create_bundle(dir:)
      source_lib_dir = File.join(dir, "source_libs")
      FileUtils.mkdir_p(source_lib_dir)
      File.write(File.join(source_lib_dir, "libruby.3.4.dylib"), "fake ruby dylib")
      File.write(File.join(source_lib_dir, "libgmp.10.dylib"), "fake gmp dylib")

      bundle_bin = File.join(dir, "bundle", "bin")
      FileUtils.mkdir_p(bundle_bin)
      File.write(File.join(bundle_bin, "ruby"), "fake binary")

      {
        binary: File.join(bundle_bin, "ruby"),
        lib_dest: File.join(dir, "bundle", "lib"),
        source_lib_dir:,
      }
    end

    def stub_dylibs(relinker, path:, libs:)
      allow(relinker).to receive(:linked_dylibs).with(path:).and_return(libs)
    end

    it "copies non-system libraries to the lib destination" do
      Dir.mktmpdir do |dir|
        bundle = create_bundle(dir:)
        source_lib = File.join(bundle.fetch(:source_lib_dir), "libruby.3.4.dylib")
        dest_lib = File.join(bundle.fetch(:lib_dest), "libruby.3.4.dylib")

        relinker = described_class.new(
          binary_path: bundle.fetch(:binary),
          lib_destination: bundle.fetch(:lib_dest),
        )

        stub_dylibs(relinker, path: bundle.fetch(:binary), libs: [
                      source_lib,
                      "/usr/lib/libSystem.B.dylib",
                    ])
        stub_dylibs(relinker, path: dest_lib, libs: [])
        allow(MachO::Tools).to receive(:change_install_name)

        relinker.relink

        expect(File.exist?(dest_lib)).to be(true)
        expect(File.read(dest_lib)).to eq("fake ruby dylib")
      end
    end

    it "rewrites load paths using MachO::Tools with @loader_path" do
      Dir.mktmpdir do |dir|
        bundle = create_bundle(dir:)
        source_lib = File.join(bundle.fetch(:source_lib_dir), "libruby.3.4.dylib")
        dest_lib = File.join(bundle.fetch(:lib_dest), "libruby.3.4.dylib")

        relinker = described_class.new(
          binary_path: bundle.fetch(:binary),
          lib_destination: bundle.fetch(:lib_dest),
        )

        stub_dylibs(relinker, path: bundle.fetch(:binary), libs: [source_lib])
        stub_dylibs(relinker, path: dest_lib, libs: [])
        allow(MachO::Tools).to receive(:change_install_name)

        relinker.relink

        expect(MachO::Tools).to have_received(:change_install_name).with(
          bundle.fetch(:binary),
          source_lib,
          "@loader_path/../lib/libruby.3.4.dylib",
        )
      end
    end

    it "skips system libraries under /usr/lib/ and /System/" do
      Dir.mktmpdir do |dir|
        bundle = create_bundle(dir:)

        relinker = described_class.new(
          binary_path: bundle.fetch(:binary),
          lib_destination: bundle.fetch(:lib_dest),
        )

        stub_dylibs(relinker, path: bundle.fetch(:binary), libs: [
                      "/usr/lib/libSystem.B.dylib",
                      "/System/Library/Frameworks/CF.framework/CF",
                    ])

        relinker.relink

        expect(Dir.exist?(bundle.fetch(:lib_dest))).to be(true)
        expect(Dir.children(bundle.fetch(:lib_dest))).to be_empty
      end
    end

    it "recursively processes dependencies of copied libraries" do
      Dir.mktmpdir do |dir|
        bundle = create_bundle(dir:)
        source_ruby = File.join(bundle.fetch(:source_lib_dir), "libruby.3.4.dylib")
        source_gmp = File.join(bundle.fetch(:source_lib_dir), "libgmp.10.dylib")
        dest_ruby = File.join(bundle.fetch(:lib_dest), "libruby.3.4.dylib")
        dest_gmp = File.join(bundle.fetch(:lib_dest), "libgmp.10.dylib")

        relinker = described_class.new(
          binary_path: bundle.fetch(:binary),
          lib_destination: bundle.fetch(:lib_dest),
        )

        stub_dylibs(relinker, path: bundle.fetch(:binary), libs: [source_ruby])
        stub_dylibs(relinker, path: dest_ruby, libs: [source_gmp])
        stub_dylibs(relinker, path: dest_gmp, libs: [])
        allow(MachO::Tools).to receive(:change_install_name)

        relinker.relink

        expect(File.exist?(dest_ruby)).to be(true)
        expect(File.exist?(dest_gmp)).to be(true)
        expect(MachO::Tools).to have_received(:change_install_name).with(
          bundle.fetch(:binary),
          source_ruby,
          "@loader_path/../lib/libruby.3.4.dylib",
        )
        expect(MachO::Tools).to have_received(:change_install_name).with(
          dest_ruby,
          source_gmp,
          "@loader_path/./libgmp.10.dylib",
        )
      end
    end

    it "does not reprocess already-handled libraries" do
      Dir.mktmpdir do |dir|
        bundle = create_bundle(dir:)
        source_gmp = File.join(bundle.fetch(:source_lib_dir), "libgmp.10.dylib")
        dest_gmp = File.join(bundle.fetch(:lib_dest), "libgmp.10.dylib")

        relinker = described_class.new(
          binary_path: bundle.fetch(:binary),
          lib_destination: bundle.fetch(:lib_dest),
        )

        stub_dylibs(relinker, path: bundle.fetch(:binary), libs: [source_gmp])
        stub_dylibs(relinker, path: dest_gmp, libs: [])
        allow(MachO::Tools).to receive(:change_install_name)

        relinker.relink

        expect(relinker).to have_received(:linked_dylibs).with(path: bundle.fetch(:binary)).once
        expect(relinker).to have_received(:linked_dylibs).with(path: dest_gmp).once
      end
    end

    it "skips a library's own install-name self-reference" do
      Dir.mktmpdir do |dir|
        bundle = create_bundle(dir:)
        source_lib = File.join(bundle.fetch(:source_lib_dir), "libruby.3.4.dylib")
        dest_lib = File.join(bundle.fetch(:lib_dest), "libruby.3.4.dylib")

        relinker = described_class.new(
          binary_path: bundle.fetch(:binary),
          lib_destination: bundle.fetch(:lib_dest),
        )

        stub_dylibs(relinker, path: bundle.fetch(:binary), libs: [source_lib])
        stub_dylibs(relinker, path: dest_lib, libs: [
                      "/some/path/libruby.3.4.dylib",
                      "/usr/lib/libSystem.B.dylib",
                    ])
        allow(MachO::Tools).to receive(:change_install_name)

        relinker.relink

        expect(MachO::Tools).to have_received(:change_install_name).once
      end
    end

    it "skips copying when the library already exists at the destination" do
      Dir.mktmpdir do |dir|
        bundle = create_bundle(dir:)
        source_lib = File.join(bundle.fetch(:source_lib_dir), "libruby.3.4.dylib")
        dest_lib = File.join(bundle.fetch(:lib_dest), "libruby.3.4.dylib")

        FileUtils.mkdir_p(bundle.fetch(:lib_dest))
        File.write(dest_lib, "already here")

        relinker = described_class.new(
          binary_path: bundle.fetch(:binary),
          lib_destination: bundle.fetch(:lib_dest),
        )

        stub_dylibs(relinker, path: bundle.fetch(:binary), libs: [source_lib])
        stub_dylibs(relinker, path: dest_lib, libs: [])
        allow(MachO::Tools).to receive(:change_install_name)

        relinker.relink

        expect(File.read(dest_lib)).to eq("already here")
      end
    end

    it "reads linked dylibs from a real binary via ruby-macho", if: RUBY_PLATFORM.include?("darwin") do
      relinker = described_class.new(
        binary_path: RbConfig.ruby,
        lib_destination: Dir.mktmpdir,
      )

      dylibs = relinker.send(:linked_dylibs, path: RbConfig.ruby)

      expect(dylibs).to be_an(Array)
      expect(dylibs).to all(be_a(String))
    end

    it "propagates MachO errors when change_install_name fails" do
      Dir.mktmpdir do |dir|
        bundle = create_bundle(dir:)
        source_lib = File.join(bundle.fetch(:source_lib_dir), "libruby.3.4.dylib")

        relinker = described_class.new(
          binary_path: bundle.fetch(:binary),
          lib_destination: bundle.fetch(:lib_dest),
        )

        stub_dylibs(relinker, path: bundle.fetch(:binary), libs: [source_lib])
        allow(MachO::Tools).to receive(:change_install_name)
          .and_raise(MachO::DylibUnknownError.new(source_lib))

        expect { relinker.relink }.to raise_error(MachO::DylibUnknownError)
      end
    end

    it "handles circular dependencies without infinite recursion" do
      Dir.mktmpdir do |dir|
        bundle = create_bundle(dir:)
        source_ruby = File.join(bundle.fetch(:source_lib_dir), "libruby.3.4.dylib")
        source_gmp = File.join(bundle.fetch(:source_lib_dir), "libgmp.10.dylib")
        dest_ruby = File.join(bundle.fetch(:lib_dest), "libruby.3.4.dylib")
        dest_gmp = File.join(bundle.fetch(:lib_dest), "libgmp.10.dylib")

        relinker = described_class.new(
          binary_path: bundle.fetch(:binary),
          lib_destination: bundle.fetch(:lib_dest),
        )

        stub_dylibs(relinker, path: bundle.fetch(:binary), libs: [source_ruby])
        stub_dylibs(relinker, path: dest_ruby, libs: [source_gmp])
        stub_dylibs(relinker, path: dest_gmp, libs: [source_ruby])
        allow(MachO::Tools).to receive(:change_install_name)

        relinker.relink

        expect(MachO::Tools).to have_received(:change_install_name).exactly(3).times
      end
    end
  end
end
