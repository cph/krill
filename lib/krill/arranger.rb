require "krill/fragment"

module Krill
  class Arranger
    attr_reader :max_line_height
    attr_reader :max_descender
    attr_reader :max_ascender
    attr_reader :finalized
    attr_accessor :consumed

    # The following present only for testing purposes
    attr_reader :unconsumed
    attr_reader :fragments
    attr_reader :current_format_state

    def initialize(options={})
      @fragments = []
      @unconsumed = []
      @kerning = options[:kerning]
    end

    def current_formatter
      current_format_state.fetch(:font)
    end

    def space_count
      fail "Lines must be finalized before calling #space_count" unless finalized

      @fragments.inject(0) do |sum, fragment|
        sum + fragment.space_count
      end
    end

    def line_width
      fail "Lines must be finalized before calling #line_width" unless finalized

      @fragments.inject(0) do |sum, fragment|
        sum + fragment.width
      end
    end

    def line
      fail "Lines must be finalized before calling #line" unless finalized

      @fragments.collect do |fragment|
        fragment.text.dup.force_encoding(::Encoding::UTF_8)
      end.join
    end

    def finalize_line
      @finalized = true

      omit_trailing_whitespace_from_line_width
      @fragments = []
      @consumed.each do |hash|
        text = hash[:text]
        format_state = hash.dup
        format_state.delete(:text)
        fragment = Krill::Fragment.new(text, format_state)
        @fragments << fragment
        set_fragment_measurements(fragment)
        set_line_measurement_maximums(fragment)
      end
    end

    def format_array=(array)
      initialize_line
      @unconsumed = []
      array.each do |hash|
        binding.pry unless hash.is_a?(Hash)
        hash[:text].scan(/[^\n]+|\n/) do |line|
          @unconsumed << hash.merge(text: line)
        end
      end
    end

    def initialize_line
      @finalized = false
      @max_line_height = 0
      @max_descender = 0
      @max_ascender = 0

      @consumed = []
      @fragments = []
    end

    def finished?
      @unconsumed.none?
    end

    def next_string
      fail "Lines must not be finalized when calling #next_string" if finalized

      next_unconsumed_hash = @unconsumed.shift

      if next_unconsumed_hash
        @consumed << next_unconsumed_hash.dup
        @current_format_state = next_unconsumed_hash.dup
        @current_format_state.delete(:text)

        next_unconsumed_hash[:text]
      end
    end

    def preview_next_string
      next_unconsumed_hash = @unconsumed.first
      next_unconsumed_hash[:text] if next_unconsumed_hash
    end

    def update_last_string(printed, unprinted, normalized_soft_hyphen = nil)
      return if printed.nil?

      if printed.empty?
        @consumed.pop
      else
        @consumed.last[:text] = printed
        @consumed.last[:normalized_soft_hyphen] = normalized_soft_hyphen if normalized_soft_hyphen
      end

      @unconsumed.unshift(@current_format_state.merge(text: unprinted)) unless unprinted.empty?

      load_previous_format_state if printed.empty?
    end

    def retrieve_fragment
      fail "Lines must be finalized before fragments can be retrieved" unless finalized

      @fragments.shift
    end

    def repack_unretrieved
      new_unconsumed = []
      while fragment = retrieve_fragment
        fragment.include_trailing_white_space!
        new_unconsumed << fragment.format_state.merge(:text => fragment.text)
      end
      @unconsumed = new_unconsumed.concat(@unconsumed)
    end

  private

    def load_previous_format_state
      if @consumed.empty?
        @current_format_state = {}
      else
        hash = @consumed.last
        @current_format_state = hash.dup
        @current_format_state.delete(:text)
      end
    end

    def omit_trailing_whitespace_from_line_width
      @consumed.reverse_each do |hash|
        if hash[:text] == "\n"
          break
        elsif hash[:text].strip.empty? && @consumed.length > 1
          # this entire fragment is trailing white space
          hash[:exclude_trailing_white_space] = true
        else
          # this fragment contains the first non-white space we have
          # encountered since the end of the line
          hash[:exclude_trailing_white_space] = true
          break
        end
      end
    end

    def set_fragment_measurements(fragment)
      fragment.width = fragment.formatter.width_of(fragment.text, kerning: @kerning)
      fragment.line_height = fragment.formatter.height
      fragment.descender = fragment.formatter.descender
      fragment.ascender = fragment.formatter.ascender
    end

    def set_line_measurement_maximums(fragment)
      @max_line_height = [defined?(@max_line_height) && @max_line_height, fragment.line_height].compact.max
      @max_descender = [defined?(@max_descender) && @max_descender, fragment.descender].compact.max
      @max_ascender = [defined?(@max_ascender) && @max_ascender, fragment.ascender].compact.max
    end

  end
end
