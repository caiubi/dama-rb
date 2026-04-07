require "spec_helper"
require "tmpdir"

RSpec.describe Dama::Release::TemplateRenderer do
  describe "#render" do
    it "renders an ERB template with the given variables" do
      renderer = described_class.new(
        template_name: "info_plist.xml.erb",
        variables: { escaped_title: "My Game" },
      )

      result = renderer.render

      expect(result).to include("<string>My Game</string>")
      expect(result).to include("CFBundleName")
      expect(result).to include("NSHighResolutionCapable")
    end

    it "renders the macOS launcher template with all variables" do
      renderer = described_class.new(
        template_name: "launcher_macos.sh.erb",
        variables: {
          native_lib_name: "libdama_native.dylib",
          ruby_version: "3.4.0",
          ruby_arch: "arm64-darwin24",
        },
      )

      result = renderer.render

      expect(result).to include("DAMA_NATIVE_LIB=\"$DIR/libdama_native.dylib\"")
      expect(result).to include("RUBYLIB=\"$DIR/ruby/lib/ruby/3.4.0:$DIR/ruby/lib/ruby/3.4.0/arm64-darwin24\"")
      expect(result).to start_with("#!/usr/bin/env bash")
    end

    it "renders the Linux launcher template with RUBYLIB" do
      renderer = described_class.new(
        template_name: "launcher_linux.sh.erb",
        variables: {
          native_lib_name: "libdama_native.so",
          ruby_version: "3.4.0",
          ruby_arch: "x86_64-linux",
        },
      )

      result = renderer.render

      expect(result).to include("RUBYLIB=\"$DIR/ruby/lib/ruby/3.4.0:$DIR/ruby/lib/ruby/3.4.0/x86_64-linux\"")
    end

    it "renders the Windows launcher template with RUBYLIB" do
      renderer = described_class.new(
        template_name: "launcher_windows.bat.erb",
        variables: {
          native_lib_name: "libdama_native.dll",
          ruby_version: "3.4.0",
          ruby_arch: "x64-mingw-ucrt",
        },
      )

      result = renderer.render

      expect(result).to include("RUBYLIB=%DIR%\\ruby\\lib\\ruby\\3.4.0;%DIR%\\ruby\\lib\\ruby\\3.4.0\\x64-mingw-ucrt")
      expect(result).to start_with("@echo off")
    end
  end
end
