module Krill
  AFM = Struct.new(:filename) do
    attr_reader :name, :family, :ascender, :descender, :line_gap,:character_widths, :kernings

    def self.open(filename)
      new filename
    end

    def initialize(filename)
      super

      data = parse(filename)

      @character_widths = data.fetch(:character_widths)
      @kernings = data.fetch(:kernings)
      attributes = data.fetch(:attributes)

      bbox = attributes['fontbbox'].split(/\s+/).map { |e| Integer(e) }
      line_height = Float(bbox[3] - bbox[1]) / 1000.0

      @name = attributes['fontname']
      @family = attributes['familyname']
      @ascender = attributes['ascender'].to_i / 1000.0
      @descender = attributes['descender'].to_i / 1000.0
      @line_gap = line_height - (ascender - descender)
    end

    def bold?
      name["Bold"].present?
    end

    def italic?
      name["Italic"].present?
    end

    def unicode?
      false
    end


  private

    def parse(filename)
      character_widths = {}
      kernings = {}
      attributes = {}
      section = []

      File.foreach(filename) do |line|
        case line
        when /^Start(\w+)/
          section.push Regexp.last_match(1)
          next
        when /^End(\w+)/
          section.pop
          next
        end

        case section
        when %w{FontMetrics CharMetrics}
          next unless line =~ /^CH?\s/

          name = line[/\bN\s+(\.?\w+)\s*;/, 1]
          char = WinAnsi.to_utf8(name)
          character_widths[char] = line[/\bWX\s+(\d+)\s*;/, 1].to_i / 1000.0

        when %w{FontMetrics KernData KernPairs}
          next unless line =~ /^KPX\s+(\.?\w+)\s+(\.?\w+)\s+(-?\d+)/

          pair = [WinAnsi.to_utf8(Regexp.last_match(1)), WinAnsi.to_utf8(Regexp.last_match(2))].join
          kerning = Regexp.last_match(3).to_i / 1000.0
          kernings[pair] = kerning unless kerning.zero?

        when %w{FontMetrics KernData TrackKern}, %w{FontMetrics Composites}
          next

        else
          line =~ /(^\w+)\s+(.*)/
          key = Regexp.last_match(1).to_s.downcase
          value = Regexp.last_match(2)
          attributes[key] = attributes[key] ? Array(attributes[key]) << value : value

        end
      end

      character_widths.freeze
      kernings.freeze
      attributes.freeze
      { character_widths: character_widths, kernings: kernings, attributes: attributes }.freeze
    end


    class WinAnsi
      def self.to_utf8(char)
        CHARACTERS.index(char)&.chr(Encoding::UTF_8)
      end

      CHARACTERS = %w{
        .notdef .notdef .notdef .notdef
        .notdef .notdef .notdef .notdef
        .notdef .notdef .notdef .notdef
        .notdef .notdef .notdef .notdef
        .notdef .notdef .notdef .notdef
        .notdef .notdef .notdef .notdef
        .notdef .notdef .notdef .notdef
        .notdef .notdef .notdef .notdef

        space exclam quotedbl numbersign
        dollar percent ampersand quotesingle
        parenleft parenright asterisk plus
        comma hyphen period slash
        zero one two three
        four five six seven
        eight nine colon semicolon
        less equal greater question

        at A B C
        D E F G
        H I J K
        L M N O
        P Q R S
        T U V W
        X Y Z bracketleft
        backslash bracketright asciicircum underscore

        grave a b c
        d e f g
        h i j k
        l m n o
        p q r s
        t u v w
        x y z braceleft
        bar braceright asciitilde .notdef

        Euro .notdef quotesinglbase florin
        quotedblbase ellipsis dagger daggerdbl
        circumflex perthousand Scaron guilsinglleft
        OE .notdef Zcaron .notdef
        .notdef quoteleft quoteright quotedblleft
        quotedblright bullet endash emdash
        tilde trademark scaron guilsinglright
        oe .notdef zcaron ydieresis

        space exclamdown cent sterling
        currency yen brokenbar section
        dieresis copyright ordfeminine guillemotleft
        logicalnot hyphen registered macron
        degree plusminus twosuperior threesuperior
        acute mu paragraph periodcentered
        cedilla onesuperior ordmasculine guillemotright
        onequarter onehalf threequarters questiondown

        Agrave Aacute Acircumflex Atilde
        Adieresis Aring AE Ccedilla
        Egrave Eacute Ecircumflex Edieresis
        Igrave Iacute Icircumflex Idieresis
        Eth Ntilde Ograve Oacute
        Ocircumflex Otilde Odieresis multiply
        Oslash Ugrave Uacute Ucircumflex
        Udieresis Yacute Thorn germandbls

        agrave aacute acircumflex atilde
        adieresis aring ae ccedilla
        egrave eacute ecircumflex edieresis
        igrave iacute icircumflex idieresis
        eth ntilde ograve oacute
        ocircumflex otilde odieresis divide
        oslash ugrave uacute ucircumflex
        udieresis yacute thorn ydieresis
      }.freeze
    end

  end
end
