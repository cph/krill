require "ttfunk"

module Krill
  class TTF
    attr_reader :ascender, :descender, :line_gap

    def self.open(filename)
      new TTFunk::File.open(filename)
    end

    def initialize(ttf)
      @ttf          = ttf
      @scale_factor = 1.0 / ttf.header.units_per_em
      @ascender     = @ttf.ascent * scale_factor
      @descender    = @ttf.descent * scale_factor
      @line_gap     = @ttf.line_gap * scale_factor
    end

    def name
      @name ||= ttf.name.font_name.reject { |family| family =~ /\x00/ }.first
    end

    def family
      @family ||= ttf.name.font_family.reject { |family| family =~ /\x00/ }.first
    end

    def bold?
      name["Bold"].present?
    end

    def italic?
      name["Italic"].present?
    end

    def character_widths
      @character_widths ||= hmtx.widths.each_with_index
        .map { |width, index| [ cmap.key(index), width ] }
        .reject { |(codepoint, width)| codepoint.nil? || width.nil? || width.zero? }
        .map { |(codepoint, width)|
          char = codepoint.chr(Encoding::UTF_8)

          # Some TTF fonts have nonzero widths for \n (UTF-8 / ASCII code: 10).
          # Patch around this as we'll never be drawing a newline with a width.
          width = 0.0 if codepoint == 10

          [ char, width * scale_factor ] }
        .to_h
    end

    def kernings
      @kernings ||= kern_pairs_table
        .map { |(a, b), kerning| [ cmap.key(a), cmap.key(b), kerning ] }
        .reject { |(a, b, kerning)| a.nil? || b.nil? || kerning.zero? }
        .map { |(a, b, kerning)|
          a = a.chr(Encoding::UTF_8)
          b = b.chr(Encoding::UTF_8)
          [ "#{a}#{b}", kerning * scale_factor ] }
        .to_h
    end

  private
    attr_reader :ttf, :scale_factor

    def cmap
      @cmap ||= ttf.cmap.unicode.first&.code_map or fail("no unicode cmap for font")
    end

    def kern_pairs_table
      return {} unless ttf.kerning.exists? && ttf.kerning.tables.any?
      ttf.kerning.tables.first.pairs
    end

    def hmtx
      ttf.horizontal_metrics
    end

  end
end
