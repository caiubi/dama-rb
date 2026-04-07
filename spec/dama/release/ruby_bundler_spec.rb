require "spec_helper"
require "tmpdir"

RSpec.describe Dama::Release::RubyBundler do
  describe "#bundle" do
    def create_path_gem(root:, name:, content:)
      lib = File.join(root, name, "lib")
      FileUtils.mkdir_p(lib)
      File.write(File.join(lib, "#{name}.rb"), content)
      lib
    end

    def create_multi_gem_project(root:)
      project = File.join(root, "myproject")
      dest = File.join(root, "release")
      FileUtils.mkdir_p([project, dest])

      gems = {
        "engine" => create_path_gem(root:, name: "engine", content: "module Engine; end"),
        "utils" => create_path_gem(root:, name: "utils", content: "module Utils; end"),
      }

      write_gemfile(project:, gems:)
      write_standalone_setup(dest:, gems:)

      [project, dest]
    end

    def write_gemfile(project:, gems:)
      lines = gems.keys.map { |name| "gem \"#{name}\", path: \"#{File.dirname(gems.fetch(name))}\"" }
      File.write(File.join(project, "Gemfile"), lines.join("\n"))
    end

    def write_standalone_setup(dest:, gems:)
      setup_dir = File.join(dest, "vendor", "bundle", "bundler")
      FileUtils.mkdir_p(setup_dir)

      lines = gems.values.map do |lib_path|
        rel = Pathname.new(lib_path).relative_path_from(Pathname.new(setup_dir))
        "$:.unshift File.expand_path(\"\#{__dir__}/#{rel}\")"
      end
      File.write(File.join(setup_dir, "setup.rb"), "#{lines.join("\n")}\n")
    end

    it "copies the ruby binary to destination/ruby/bin/" do
      Dir.mktmpdir do |dest|
        Dir.mktmpdir do |project|
          bundler = described_class.new(destination: dest, project_root: project)
          allow(bundler).to receive(:install_gems)

          bundler.bundle

          ruby_bin = File.join(dest, "ruby", "bin", File.basename(RbConfig.ruby))
          expect(File.exist?(ruby_bin)).to be(true)
        end
      end
    end

    it "copies ruby stdlib to destination/ruby/lib/" do
      Dir.mktmpdir do |dest|
        Dir.mktmpdir do |project|
          bundler = described_class.new(destination: dest, project_root: project)
          allow(bundler).to receive(:install_gems)

          bundler.bundle

          ruby_version = RbConfig::CONFIG.fetch("ruby_version")
          lib_dir = File.join(dest, "ruby", "lib", "ruby", ruby_version)
          expect(File.directory?(lib_dir)).to be(true)
        end
      end
    end

    it "copies the ruby shared library to destination/ruby/lib/" do
      Dir.mktmpdir do |dest|
        Dir.mktmpdir do |project|
          bundler = described_class.new(destination: dest, project_root: project)
          allow(bundler).to receive(:install_gems)

          bundler.bundle

          shared_lib = RbConfig::CONFIG.fetch("LIBRUBY_SO")
          shared_lib_path = File.join(dest, "ruby", "lib", shared_lib)
          expect(File.exist?(shared_lib_path)).to be(true)
        end
      end
    end

    it "returns the ruby destination path" do
      Dir.mktmpdir do |dest|
        Dir.mktmpdir do |project|
          bundler = described_class.new(destination: dest, project_root: project)
          allow(bundler).to receive(:install_gems)

          result = bundler.bundle

          expect(result).to eq(File.join(dest, "ruby"))
        end
      end
    end

    it "runs bundle install --standalone using env vars for path and gemfile" do
      Dir.mktmpdir do |dest|
        Dir.mktmpdir do |project|
          gemfile = File.join(project, "Gemfile")
          File.write(gemfile, "source 'https://rubygems.org'")

          bundler = described_class.new(destination: dest, project_root: project)
          allow(bundler).to receive(:system).and_return(true)
          allow(bundler).to receive(:copy_ruby_runtime)

          bundler.bundle

          vendor_dir = File.join(dest, "vendor", "bundle")
          expect(File.directory?(vendor_dir)).to be(true)
          expect(bundler).to have_received(:system).with(
            { "BUNDLE_PATH" => vendor_dir, "BUNDLE_GEMFILE" => gemfile },
            "bundle", "install", "--standalone"
          )
        end
      end
    end

    it "skips gem install when project has no Gemfile" do
      Dir.mktmpdir do |dest|
        Dir.mktmpdir do |project|
          bundler = described_class.new(destination: dest, project_root: project)
          allow(bundler).to receive(:copy_ruby_runtime)

          expect { bundler.bundle }.not_to raise_error
          expect(File.directory?(File.join(dest, "vendor", "bundle"))).to be(true)
        end
      end
    end

    it "raises when bundle install fails" do
      Dir.mktmpdir do |dest|
        Dir.mktmpdir do |project|
          File.write(File.join(project, "Gemfile"), "source 'https://rubygems.org'")

          bundler = described_class.new(destination: dest, project_root: project)
          allow(bundler).to receive(:system).and_return(false)
          allow(bundler).to receive(:copy_ruby_runtime)

          expect { bundler.bundle }.to raise_error(RuntimeError, "Gem bundling failed")
        end
      end
    end

    it "skips shared library copy when LIBRUBY_SO is empty" do
      Dir.mktmpdir do |dest|
        Dir.mktmpdir do |project|
          bundler = described_class.new(destination: dest, project_root: project)
          allow(bundler).to receive(:install_gems)

          stub_const("RbConfig::CONFIG", RbConfig::CONFIG.merge("LIBRUBY_SO" => ""))

          bundler.bundle

          lib_dir = File.join(dest, "ruby", "lib")
          dylibs = Dir.glob(File.join(lib_dir, "*.dylib")) + Dir.glob(File.join(lib_dir, "*.so"))
          expect(dylibs).to be_empty
        end
      end
    end

    it "skips shared library copy when source file does not exist" do
      Dir.mktmpdir do |dest|
        Dir.mktmpdir do |project|
          bundler = described_class.new(destination: dest, project_root: project)
          allow(bundler).to receive(:install_gems)

          stub_const("RbConfig::CONFIG", RbConfig::CONFIG.merge(
                                           "LIBRUBY_SO" => "libruby_nonexistent.dylib",
                                           "libdir" => "/nonexistent/path",
                                         ))

          bundler.bundle

          lib_dir = File.join(dest, "ruby", "lib")
          expect(File.exist?(File.join(lib_dir, "libruby_nonexistent.dylib"))).to be(false)
        end
      end
    end

    it "embeds path gems and rewrites setup.rb after bundle install" do
      Dir.mktmpdir do |root|
        project = File.join(root, "myproject")
        dest = File.join(root, "release")
        FileUtils.mkdir_p([project, dest])

        gem_lib = File.join(project, "lib")
        FileUtils.mkdir_p(gem_lib)
        File.write(File.join(gem_lib, "mygem.rb"), "module MyGem; end")

        gemfile = File.join(project, "Gemfile")
        File.write(gemfile, 'gem "mygem", path: "."')

        vendor_dir = File.join(dest, "vendor", "bundle")
        setup_dir = File.join(vendor_dir, "bundler")
        FileUtils.mkdir_p(setup_dir)

        # Simulate the setup.rb that `bundle --standalone` generates,
        # using the actual relative path from bundler dir to the gem's lib
        rel_path = Pathname.new(gem_lib).relative_path_from(Pathname.new(setup_dir))
        setup_content = "$:.unshift File.expand_path(\"\#{__dir__}/#{rel_path}\")\n"
        File.write(File.join(setup_dir, "setup.rb"), setup_content)

        bundler = described_class.new(destination: dest, project_root: project)
        allow(bundler).to receive(:copy_ruby_runtime)
        allow(bundler).to receive(:system).and_return(true)

        bundler.bundle

        embedded = File.join(vendor_dir, "path_gems", "mygem", "lib", "mygem.rb")
        expect(File.exist?(embedded)).to be(true)
        expect(File.read(embedded)).to eq("module MyGem; end")

        result = File.read(File.join(setup_dir, "setup.rb"))
        expect(result).to include("path_gems/mygem/lib")
        expect(result).not_to include(rel_path.to_s)
      end
    end

    it "skips path gem embedding when Gemfile has no path gems" do
      Dir.mktmpdir do |root|
        project = File.join(root, "myproject")
        dest = File.join(root, "release")
        FileUtils.mkdir_p([project, dest])

        gemfile = File.join(project, "Gemfile")
        File.write(gemfile, "source \"https://rubygems.org\"\ngem \"ffi\"")

        vendor_dir = File.join(dest, "vendor", "bundle")
        setup_dir = File.join(vendor_dir, "bundler")
        FileUtils.mkdir_p(setup_dir)
        original = "$:.unshift File.expand_path(\"\#{__dir__}/../ruby/3.4.0/gems/ffi-1.17.3/lib\")\n"
        File.write(File.join(setup_dir, "setup.rb"), original)

        bundler = described_class.new(destination: dest, project_root: project)
        allow(bundler).to receive(:copy_ruby_runtime)
        allow(bundler).to receive(:system).and_return(true)

        bundler.bundle

        expect(File.read(File.join(setup_dir, "setup.rb"))).to eq(original)
      end
    end

    it "preserves non-$:.unshift lines in setup.rb like comments and blank lines" do
      Dir.mktmpdir do |root|
        project = File.join(root, "myproject")
        dest = File.join(root, "release")
        FileUtils.mkdir_p([project, dest])

        gem_lib = File.join(project, "lib")
        FileUtils.mkdir_p(gem_lib)
        File.write(File.join(gem_lib, "mygem.rb"), "module MyGem; end")

        gemfile = File.join(project, "Gemfile")
        File.write(gemfile, "gem \"mygem\", path: \".\"")

        vendor_dir = File.join(dest, "vendor", "bundle")
        setup_dir = File.join(vendor_dir, "bundler")
        FileUtils.mkdir_p(setup_dir)

        rel_path = Pathname.new(gem_lib).relative_path_from(Pathname.new(setup_dir))
        setup_content = "# Auto-generated by bundler\n" \
                        "$:.unshift File.expand_path(\"\#{__dir__}/#{rel_path}\")\n"
        File.write(File.join(setup_dir, "setup.rb"), setup_content)

        bundler = described_class.new(destination: dest, project_root: project)
        allow(bundler).to receive(:copy_ruby_runtime)
        allow(bundler).to receive(:system).and_return(true)

        bundler.bundle

        result = File.read(File.join(setup_dir, "setup.rb"))
        expect(result).to include("# Auto-generated by bundler")
        expect(result).to include("path_gems/mygem/lib")
      end
    end

    it "leaves non-path gem lines in setup.rb unchanged" do
      Dir.mktmpdir do |root|
        project = File.join(root, "myproject")
        dest = File.join(root, "release")
        FileUtils.mkdir_p([project, dest])

        gem_lib = File.join(project, "lib")
        FileUtils.mkdir_p(gem_lib)
        File.write(File.join(gem_lib, "mygem.rb"), "module MyGem; end")

        gemfile = File.join(project, "Gemfile")
        File.write(gemfile, "source \"https://rubygems.org\"\ngem \"mygem\", path: \".\"")

        vendor_dir = File.join(dest, "vendor", "bundle")
        setup_dir = File.join(vendor_dir, "bundler")
        FileUtils.mkdir_p(setup_dir)

        rel_path = Pathname.new(gem_lib).relative_path_from(Pathname.new(setup_dir))
        setup_content = <<~SETUP
          $:.unshift File.expand_path("\#{__dir__}/../\#{RUBY_ENGINE}/\#{Gem.ruby_api_version}/gems/ffi-1.17.3/lib")
          $:.unshift File.expand_path("\#{__dir__}/#{rel_path}")
        SETUP
        File.write(File.join(setup_dir, "setup.rb"), setup_content)

        bundler = described_class.new(destination: dest, project_root: project)
        allow(bundler).to receive(:copy_ruby_runtime)
        allow(bundler).to receive(:system).and_return(true)

        bundler.bundle

        result = File.read(File.join(setup_dir, "setup.rb"))
        expect(result).to include("ffi-1.17.3/lib")
        expect(result).to include("path_gems/mygem/lib")
      end
    end

    it "correctly rewrites setup.rb when multiple path gems are present" do
      Dir.mktmpdir do |root|
        project, dest = create_multi_gem_project(root:)
        vendor_dir = File.join(dest, "vendor", "bundle")
        setup_dir = File.join(vendor_dir, "bundler")

        bundler = described_class.new(destination: dest, project_root: project)
        allow(bundler).to receive(:copy_ruby_runtime)
        allow(bundler).to receive(:system).and_return(true)

        bundler.bundle

        expect(File.read(File.join(vendor_dir, "path_gems", "engine", "lib", "engine.rb")))
          .to eq("module Engine; end")
        expect(File.read(File.join(vendor_dir, "path_gems", "utils", "lib", "utils.rb")))
          .to eq("module Utils; end")

        result = File.read(File.join(setup_dir, "setup.rb"))
        expect(result).to include("path_gems/engine/lib")
        expect(result).to include("path_gems/utils/lib")
      end
    end
  end
end
