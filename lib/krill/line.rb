module Krill
  class Line
    attr_reader :text, :width

    def initialize(text, width)
      @text = text
      @width = width
    end

    alias :to_s :text
    alias :to_str :text

  end
end
