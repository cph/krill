module Krill
  Formatter = Struct.new(:font, :size, :character_spacing) do

    def initialize(font, size, character_spacing: 0)
      super font, size, character_spacing
    end

    def name
      font.name
    end

    def family
      font.family
    end


    def width_of(string, kerning: true)
      length = compute_width_of(string, kerning: kerning)
      length + (character_spacing * character_count(string))
    end

    # NOTE: +string+ must be UTF8-encoded.
    def compute_width_of(string, kerning: true)
      if kerning
        kern(string).inject(0.0) do |width, r|
          if r.is_a?(Numeric)
            width - r
          else
            r.inject(width) { |width2, char| width2 + width_of_char(char) }
          end
        end
      else
        string.chars.inject(0.0) { |width, char| width + width_of_char(char) }
      end * size
    end


    def ascender
      font.ascender * size
    end

    def descender
      -font.descender * size
    end

    def line_gap
      font.line_gap * size
    end

    def height
      normalized_height * size
    end


    def superscript?
      false # <-- TODO
    end

    def subscript?
      false # <-- TODO
    end


    def unicode?
      true
    end

    def normalize_encoding(text)
      text.encode(::Encoding::UTF_8)
    end


  private


    def normalized_height
      @normalized_height ||= font.ascender - font.descender + font.line_gap
    end

    # Returns the number of characters in +str+ (a UTF-8-encoded string).
    def character_count(str)
      str.length
    end

    # +string+ must be UTF8-encoded.
    #
    # Returns an array. If an element is a numeric, it represents the
    # kern amount to inject at that position. Otherwise, the element
    # is an array of UTF-16 characters.
    def kern(string)
      a = []

      string.each_char do |char|
        if a.empty?
          a << [char]
        elsif (kern = kerning_for_chars(a.last.last, char))
          a << -kern << [char]
        else
          a.last << char
        end
      end

      a
    end


  protected


    def width_of_char(char)
      font.character_widths.fetch(char, 0.0)
    end

    def kerning_for_chars(char0, char1)
      font.kernings["#{char0}#{char1}"]
    end


  end
end
