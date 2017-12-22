module Krill
  class Fragment
    attr_reader :format_state, :text
    attr_writer :width
    attr_accessor :line_height, :descender, :ascender
    attr_accessor :word_spacing, :left, :baseline

    attr_reader :font
    alias formatter font

    def initialize(text, format_state)
      @format_state = format_state
      @font = format_state.fetch(:font)
      @word_spacing = 0

      # keep the original value of "text", so we can reinitialize @text if formatting parameters
      #   like text direction are changed
      @original_text = text
      @text = process_text(@original_text)
    end

    def width
      return @width if @word_spacing.zero?
      @width + @word_spacing * space_count
    end

    def height
      top - bottom
    end

    def superscript?
      formatter.superscript?
    end

    def subscript?
      formatter.subscript?
    end

    def character_spacing
      formatter.character_spacing
    end

    def y_offset
      if subscript? then -descender
      elsif superscript? then 0.85 * ascender
      else 0
      end
    end

    def underline_points
      y = baseline - 1.25
      [[left, y], [right, y]]
    end

    def strikethrough_points
      y = baseline + ascender * 0.3
      [[left, y], [right, y]]
    end

    def direction
      @format_state[:direction]
    end

    def default_direction=(direction)
      unless @format_state[:direction]
        @format_state[:direction] = direction
        @text = process_text(@original_text)
      end
    end

    def include_trailing_white_space!
      @format_state.delete(:exclude_trailing_white_space)
      @text = process_text(@original_text)
    end

    def space_count
      @text.count(" ")
    end

    def right
      left + width
    end

    def top
      baseline + ascender
    end

    def bottom
      baseline - descender
    end

  private

    def process_text(text)
      string = strip_zero_width_spaces(text)

      if exclude_trailing_white_space?
        string = string.rstrip

        if soft_hyphens_need_processing?(string)
          string = process_soft_hyphens(string[0..-2]) + string[-1..-1]
        end
      else
        if soft_hyphens_need_processing?(string)
          string = process_soft_hyphens(string)
        end
      end

      case direction
      when :rtl
        string.reverse
      else
        string
      end
    end

    def exclude_trailing_white_space?
      @format_state[:exclude_trailing_white_space]
    end

    def soft_hyphens_need_processing?(string)
      string.length > 0 && normalized_soft_hyphen
    end

    def normalized_soft_hyphen
      @format_state[:normalized_soft_hyphen]
    end

    def process_soft_hyphens(string)
      if string.encoding != normalized_soft_hyphen.encoding
        string.force_encoding(normalized_soft_hyphen.encoding)
      end

      string.gsub(normalized_soft_hyphen, "")
    end

    def strip_zero_width_spaces(string)
      if string.encoding == ::Encoding::UTF_8
        string.gsub(ZWSP, "")
      else
        string
      end
    end

  end
end
