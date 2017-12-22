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
        kern(string).inject(0) do |s, r|
          if r.is_a?(Numeric)
            s - r
          else
            r.inject(s) { |s2, u| s2 + font.character_widths.fetch(u, 0) }
          end
        end * size
      else
        string.chars.inject(0) do |sum, char|
          sum + font.character_widths.fetch(char, 0.0)
        end * size
      end
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
        elsif (kern = font.kernings["#{a.last.last}#{char}"])
          a << -kern << [char]
        else
          a.last << char
        end
      end

      a
    end

  end
end
