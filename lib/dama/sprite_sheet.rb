module Dama
  # Calculates UV coordinates for individual frames within a
  # sprite sheet / texture atlas.
  class SpriteSheet
    attr_reader :frame_width, :frame_height, :columns, :rows, :frame_count

    def initialize(texture_width:, texture_height:, frame_width:, frame_height:)
      @frame_width = frame_width.to_f
      @frame_height = frame_height.to_f
      @texture_width = texture_width.to_f
      @texture_height = texture_height.to_f
      @columns = (texture_width / frame_width).to_i
      @rows = (texture_height / frame_height).to_i
      @frame_count = columns * rows
    end

    # Returns normalized UV coordinates for a given frame index.
    # frame: 0-based index, left-to-right then top-to-bottom.
    def frame_uv(frame:)
      clamped = frame.clamp(0, frame_count - 1)
      col = clamped % columns
      row = clamped / columns

      u = (col * frame_width) / texture_width
      v = (row * frame_height) / texture_height
      u2 = ((col + 1) * frame_width) / texture_width
      v2 = ((row + 1) * frame_height) / texture_height

      { u:, v:, u2:, v2: }
    end

    private

    attr_reader :texture_width, :texture_height
  end
end
