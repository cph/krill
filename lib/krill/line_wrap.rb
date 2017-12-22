module Krill
  class LineWrap

    # The width of the last wrapped line
    #
    def width
      @accumulated_width || 0
    end

    # The number of spaces in the last wrapped line
    attr_reader :space_count
    attr_reader :soft_hyphen
    attr_reader :zero_width_space

    # Whether this line is the last line in the paragraph
    def paragraph_finished?
      @newline_encountered || is_next_string_newline? || @arranger.finished?
    end

    def tokenize(fragment)
      fragment.scan(scan_pattern)
    end

    # Work in conjunction with the PDF::Formatted::Arranger
    # defined in the :arranger option to determine what formatted text
    # will fit within the width defined by the :width option
    #
    def wrap_line(width:, arranger:, kerning: nil, disable_wrap_by_char: nil)
      initialize_line(
        kerning: kerning,
        width: width,
        arranger: arranger,
        disable_wrap_by_char: disable_wrap_by_char)

      while fragment = @arranger.next_string
        @fragment_output = ""

        fragment.lstrip! if first_fragment_on_this_line?(fragment)
        next if empty_line?(fragment)

        break unless apply_font_settings_and_add_fragment_to_line(fragment)
      end

      @arranger.finalize_line
      @accumulated_width = @arranger.line_width
      @space_count = @arranger.space_count
      @arranger.line
    end

  private

    def first_fragment_on_this_line?(fragment)
      line_empty? && fragment != "\n"
    end

    def empty_line?(fragment)
      empty = line_empty? && fragment.empty? && is_next_string_newline?
      @arranger.update_last_string("", "", soft_hyphen) if empty
      empty
    end

    def is_next_string_newline?
      @arranger.preview_next_string == "\n"
    end

    def apply_font_settings_and_add_fragment_to_line(fragment)
      # if font has changed from Unicode to non-Unicode, or vice versa,
      # the characters used for soft hyphens and zero-width spaces will
      # be different.
      set_soft_hyphen_and_zero_width_space(@arranger.current_formatter)
      add_fragment_to_line(fragment, @arranger.current_formatter)
    end

    # returns true if all text was printed without running into the end of
    # the line
    #
    def add_fragment_to_line(fragment, formatter)
      if fragment == ""
        true
      elsif fragment == "\n"
        @newline_encountered = true
        false
      else
        tokenize(fragment).each do |segment|
          if segment == zero_width_space
            segment_width = 0
          else
            segment_width = formatter.width_of(segment, kerning: @kerning)
          end

          if @accumulated_width + segment_width <= @width
            @accumulated_width += segment_width
            if segment[-1] == soft_hyphen
              sh_width = formatter.width_of("#{soft_hyphen}", kerning: @kerning)
              @accumulated_width -= sh_width
            end
            @fragment_output += segment
          else
            end_of_the_line_reached(formatter, segment)
            fragment_finished(fragment)
            return false
          end
        end

        fragment_finished(fragment)
        true
      end
    end



    # The pattern used to determine chunks of text to place on a given line
    #
    def scan_pattern(encoding = ::Encoding::UTF_8)
      ebc = break_chars(encoding)
      eshy = soft_hyphen(encoding)
      ehy = hyphen(encoding)
      ews = whitespace(encoding)

      patterns = [
        "[^#{ebc}]+#{eshy}",
        "[^#{ebc}]+#{ehy}+",
        "[^#{ebc}]+",
        "[#{ews}]+",
        "#{ehy}+[^#{ebc}]*",
        eshy.to_s
      ]

      pattern = patterns
        .map { |p| p.encode(encoding) }
        .join('|')

      Regexp.new(pattern)
    end

    # The pattern used to determine whether any word breaks exist on a
    # current line, which in turn determines whether character level
    # word breaking is needed
    #
    def word_division_scan_pattern(encoding = ::Encoding::UTF_8)
      common_whitespaces = ["\t", "\n", "\v", "\r", ' '].map do |c|
        c.encode(encoding)
      end

      Regexp.union(
        common_whitespaces +
        [
          zero_width_space(encoding),
          soft_hyphen(encoding),
          hyphen(encoding)
        ].compact
      )
    end

    def soft_hyphen(encoding = ::Encoding::UTF_8)
      Krill::SHY.encode(encoding)
    end

    def break_chars(encoding = ::Encoding::UTF_8)
      [
        whitespace(encoding),
        soft_hyphen(encoding),
        hyphen(encoding)
      ].join('')
    end

    def zero_width_space(encoding = ::Encoding::UTF_8)
      Krill::ZWSP.encode(encoding)
    end

    def whitespace(encoding = ::Encoding::UTF_8)
      "\s\t#{zero_width_space(encoding)}".encode(encoding)
    end

    def hyphen(_encoding = ::Encoding::UTF_8)
      '-'
    end



    def line_empty?
      @line_empty && @accumulated_width == 0
    end

    def initialize_line(kerning:, width:, arranger:, disable_wrap_by_char:)
      @kerning = kerning
      @width = width

      @disable_wrap_by_char = disable_wrap_by_char

      @accumulated_width = 0
      @line_empty = true
      @line_contains_more_than_one_word = false

      @arranger = arranger
      @arranger.initialize_line

      @newline_encountered = false
      @line_full = false
    end

    def set_soft_hyphen_and_zero_width_space(formatter)
      # this is done once per fragment, after the font settings for the fragment are applied --
      #   it could actually be skipped if the font hasn't changed
      @soft_hyphen = formatter.normalize_encoding(SHY)
      @zero_width_space = formatter.unicode? ? ZWSP : ""
    end

    def fragment_finished(fragment)
      if fragment == "\n"
        @newline_encountered = true
        @line_empty = false
      else
        update_output_based_on_last_fragment(fragment, soft_hyphen)
        update_line_status_based_on_last_output
        determine_whether_to_pull_preceding_fragment_to_join_this_one(fragment)
      end
      remember_this_fragment_for_backward_looking_ops
    end

    def update_output_based_on_last_fragment(fragment, normalized_soft_hyphen = nil)
      remaining_text = fragment.slice(@fragment_output.length..fragment.length)
      fail CannotFit if line_finished? && line_empty? && @fragment_output.empty? && !fragment.strip.empty?
      @arranger.update_last_string(@fragment_output, remaining_text, normalized_soft_hyphen)
    end

    def determine_whether_to_pull_preceding_fragment_to_join_this_one(current_fragment)
      if @fragment_output.empty? && !current_fragment.empty? && @line_contains_more_than_one_word
        unless previous_fragment_ended_with_breakable? || fragment_begins_with_breakable?(current_fragment)
          @fragment_output = @previous_fragment_output_without_last_word
          update_output_based_on_last_fragment(@previous_fragment)
        end
      end
    end

    def remember_this_fragment_for_backward_looking_ops
      @previous_fragment = @fragment_output.dup
      pf = @previous_fragment
      @previous_fragment_ended_with_breakable = pf =~ /[#{break_chars}]$/
      last_word = pf.slice(/[^#{break_chars}]*$/)
      last_word_length = last_word.nil? ? 0 : last_word.length
      @previous_fragment_output_without_last_word = pf.slice(0, pf.length - last_word_length)
    end

    def previous_fragment_ended_with_breakable?
      @previous_fragment_ended_with_breakable
    end

    def fragment_begins_with_breakable?(fragment)
      fragment =~ /^[#{break_chars}]/
    end

    def line_finished?
      @line_full || paragraph_finished?
    end

    def update_line_status_based_on_last_output
      @line_contains_more_than_one_word = true if @fragment_output =~ word_division_scan_pattern
    end

    def end_of_the_line_reached(formatter, segment)
      update_line_status_based_on_last_output
      wrap_by_char(formatter, segment) unless @disable_wrap_by_char || @line_contains_more_than_one_word
      @line_full = true
    end

    def wrap_by_char(formatter, segment)
      segment.each_char do |char|
        break unless append_char(char, formatter)
      end
    end

    def append_char(char, formatter)
      # kerning doesn't make sense in the context of a single character
      char_width = formatter.compute_width_of(char, kerning: false)

      if @accumulated_width + char_width <= @width
        @accumulated_width += char_width
        @fragment_output << char
        true
      else
        false
      end
    end

  end
end
