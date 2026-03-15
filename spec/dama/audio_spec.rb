require "spec_helper"
require "tmpdir"

RSpec.describe Dama::Audio do
  subject(:audio) { described_class.new(backend:) }

  include_context "with headless backend"

  describe "#load" do
    it "loads a sound file and stores the handle" do
      Dir.mktmpdir do |dir|
        # Create a minimal WAV file (44 bytes header + 0 data = valid empty WAV).
        path = File.join(dir, "test.wav")
        write_minimal_wav(path)

        handle = audio.load(name: :test, path:)
        expect(handle).to be_a(Integer)
        expect(handle).to be > 0
      end
    end
  end

  describe "#play" do
    it "plays a loaded sound without error" do
      Dir.mktmpdir do |dir|
        path = File.join(dir, "test.wav")
        write_minimal_wav(path)

        audio.load(name: :test, path:)
        expect { audio.play(:test) }.not_to raise_error
      end
    end

    it "raises KeyError for unknown sound" do
      expect { audio.play(:nonexistent) }.to raise_error(KeyError)
    end

    it "plays a looping sound without error" do
      Dir.mktmpdir do |dir|
        path = File.join(dir, "test.wav")
        write_minimal_wav(path)

        audio.load(name: :loop_test, path:)
        expect { audio.play(:loop_test, loop: true) }.not_to raise_error
        audio.stop_all
      end
    end
  end

  describe "#load with invalid file" do
    it "raises when the file does not exist" do
      expect { audio.load(name: :bad, path: "/nonexistent/file.wav") }
        .to raise_error(RuntimeError, /Failed to load sound/)
    end
  end

  describe "#stop_all" do
    it "stops all sounds without error" do
      expect { audio.stop_all }.not_to raise_error
    end
  end

  describe "#unload" do
    it "unloads a specific sound" do
      Dir.mktmpdir do |dir|
        path = File.join(dir, "test.wav")
        write_minimal_wav(path)

        audio.load(name: :test, path:)
        expect { audio.unload(:test) }.not_to raise_error
      end
    end

    it "does nothing for unknown sound names" do
      expect { audio.unload(:nonexistent) }.not_to raise_error
    end
  end

  describe "#unload_all" do
    it "unloads all sounds" do
      Dir.mktmpdir do |dir|
        path = File.join(dir, "test.wav")
        write_minimal_wav(path)

        audio.load(name: :one, path:)
        audio.load(name: :two, path:)
        expect { audio.unload_all }.not_to raise_error
      end
    end
  end
end
