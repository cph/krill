module Krill
  class WrappedText

    def initialize(text_box)
      @text_box = text_box
    end

    def height
      @text_box.height
    end

    def lines
      @text_box.instance_variable_get :@printed_lines
    end

  end
end
