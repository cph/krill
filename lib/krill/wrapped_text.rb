module Krill
  class WrappedText

    def initialize(text_box)
      @text_box = text_box
    end

    def height
      @text_box.height
    end

    def lines
      @text_box.printed_lines.map(&:to_s)
    end

    def width
      @text_box.printed_lines.map(&:width).max
    end

  end
end
