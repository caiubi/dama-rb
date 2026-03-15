# Writes a minimal valid WAV file for audio tests.
module WavHelper
  HEADER_SIZE = 44
  SAMPLE_RATE = 44_100
  BITS = 16
  CHANNELS = 1

  def write_minimal_wav(path)
    data_size = 2 # 1 sample * 2 bytes
    File.open(path, "wb") do |f|
      write_wav_header(f, data_size:)
      f.write([0].pack("v")) # 1 silent sample
    end
  end

  private

  def write_wav_header(file, data_size:)
    byte_rate = SAMPLE_RATE * CHANNELS * BITS / 8
    block_align = CHANNELS * BITS / 8

    file.write("RIFF")
    file.write([36 + data_size].pack("V"))
    file.write("WAVEfmt ")
    file.write([16, 1].pack("Vv"))
    file.write([CHANNELS, SAMPLE_RATE].pack("vV"))
    file.write([byte_rate, block_align, BITS].pack("Vvv"))
    file.write("data")
    file.write([data_size].pack("V"))
  end
end

RSpec.configure do |config|
  config.include WavHelper
end
