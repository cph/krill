require "krill/line_wrap"
require "krill/line"
require "krill/arranger"

module Krill
  class TextBox
    attr_reader :printed_lines

    def initialize(formatted_text, options={})
      @original_array       = formatted_text
      @text                 = nil
      @at                   = [0, 720.0] # was [ @document.bounds.left, @document.bounds.top ]
      @width                = options.fetch(:width)
      @height               = options.fetch(:height, @at[1])
      @direction            = options.fetch(:direction, :ltr)
      @align                = options.fetch(:align, @direction == :rtl ? :right : :left)
      @leading              = options.fetch(:leading, 0)
      @kerning              = options.fetch(:kerning, true)
      @disable_wrap_by_char = options[:disable_wrap_by_char]
      @line_wrap            = Krill::LineWrap.new
      @arranger             = Krill::Arranger.new(kerning: @kerning)
    end

    def render
      wrap(normalize_encoding(original_text))
    end

    # The text that was successfully printed (or, if <tt>dry_run</tt> was
    # used, the text that would have been successfully printed)
    attr_reader :text

    # True if nothing printed (or, if <tt>dry_run</tt> was
    # used, nothing would have been successfully printed)
    def nothing_printed?
      @nothing_printed
    end

    # True if everything printed (or, if <tt>dry_run</tt> was
    # used, everything would have been successfully printed)
    def everything_printed?
      @everything_printed
    end

    # The upper left corner of the text box
    attr_reader :at

    # The line height of the last line printed
    attr_reader :line_height

    # The height of the ascender of the last line printed
    attr_reader :ascender

    # The height of the descender of the last line printed
    attr_reader :descender

    # The leading used during printing
    attr_reader :leading

    def line_gap
      line_height - (ascender + descender)
    end

    # The height actually used during the previous <tt>render</tt>
    def height
      return 0 if @baseline_y.nil? || @descender.nil?
      (@baseline_y - @descender).abs
    end

  private

    # The width available at this point in the box
    def available_width
      @width
    end

    # <tt>fragment</tt> is a Krill::Fragment object
    def draw_fragment(fragment, accumulated_width=0, line_width=0, word_spacing=0)
      case @align
      when :left
        x = @at[0]
      when :center
        x = @at[0] + @width * 0.5 - line_width * 0.5
      when :right
        x = @at[0] + @width - line_width
      when :justify
        x = if @direction == :ltr
              @at[0]
            else
              @at[0] + @width - line_width
            end
      end

      x += accumulated_width

      y = @at[1] + @baseline_y

      y += fragment.y_offset

      fragment.left = x
      fragment.baseline = y
    end

    def original_text
      @original_array.collect(&:dup)
    end

    def normalize_encoding(text)
      text.each do |hash|
        hash[:text] = hash.fetch(:font).normalize_encoding(hash.fetch(:text))
      end
    end

    def move_baseline_down
      if @baseline_y.zero?
        @baseline_y = -@ascender
      else
        @baseline_y -= (@line_height + @leading)
      end
    end

    # See the developer documentation for PDF::Core::Text#wrap
    #
    # Formatted#wrap should set the following variables:
    #   <tt>@line_height</tt>::
    #        the height of the tallest fragment in the last printed line
    #   <tt>@descender</tt>::
    #        the descender height of the tallest fragment in the last
    #        printed line
    #   <tt>@ascender</tt>::
    #        the ascender heigth of the tallest fragment in the last
    #        printed line
    #   <tt>@baseline_y</tt>::
    #       the baseline of the current line
    #   <tt>@nothing_printed</tt>::
    #       set to true until something is printed, then false
    #   <tt>@everything_printed</tt>::
    #       set to false until everything printed, then true
    #
    # Returns any formatted text that was not printed
    #
    def wrap(array)
      initialize_wrap(array)

      stop = false
      until stop
        # wrap before testing if enough height for this line because the
        # height of the highest fragment on this line will be used to
        # determine the line height
        @line_wrap.wrap_line(
          kerning: @kerning,
          width: available_width,
          arranger: @arranger,
          disable_wrap_by_char: @disable_wrap_by_char)

        if enough_height_for_this_line?
          move_baseline_down
          print_line
        else
          stop = true
        end

        stop ||= @arranger.finished?
      end
      @text = @printed_lines.join("\n")
      @everything_printed = @arranger.finished?
      @arranger.unconsumed
    end

    def print_line
      @nothing_printed = false
      printed_fragments = []
      fragments_this_line = []

      word_spacing = word_spacing_for_this_line
      @arranger.fragments.each do |fragment|
        fragment.word_spacing = word_spacing
        if fragment.text == "\n"
          printed_fragments << "\n" if @printed_lines.last == ""
          break
        end
        printed_fragments << fragment.text
        fragments_this_line << fragment
      end
      @arranger.fragments.replace []

      accumulated_width = 0
      fragments_this_line.reverse! if @direction == :rtl
      fragments_this_line.each do |fragment_this_line|
        fragment_this_line.default_direction = @direction
        format_and_draw_fragment(fragment_this_line, accumulated_width, @line_wrap.width, word_spacing)
        accumulated_width += fragment_this_line.width
      end

      text = printed_fragments.map { |s| s.force_encoding(::Encoding::UTF_8) }.join
      @printed_lines << Krill::Line.new(text, accumulated_width)
    end

    def word_spacing_for_this_line
      if @align == :justify && @line_wrap.space_count > 0 && !@line_wrap.paragraph_finished?
        (available_width - @line_wrap.width) / @line_wrap.space_count
      else
        0
      end
    end

    def enough_height_for_this_line?
      @line_height = @arranger.max_line_height
      @descender = @arranger.max_descender
      @ascender = @arranger.max_ascender
      diff = if @baseline_y.zero?
               @ascender + @descender
             else
               @descender + @line_height + @leading
             end
      require_relatived_total_height = @baseline_y.abs + diff
      if require_relatived_total_height > @height + 0.0001
        # no room for the full height of this line
        @arranger.repack_unretrieved
        false
      else
        true
      end
    end

    def initialize_wrap(array)
      @text = nil
      @arranger.format_array = array

      # these values will depend on the maximum value within a given line
      @line_height = 0
      @descender = 0
      @ascender = 0
      @baseline_y = 0

      @printed_lines = []
      @nothing_printed = true
      @everything_printed = false
    end

    def format_and_draw_fragment(fragment, accumulated_width, line_width, word_spacing)
      draw_fragment(fragment, accumulated_width, line_width, word_spacing)
    end

  end
end
