require 'spec_helper'

describe Krill::LineWrap do
  let(:font) { Krill.formatter }
  let(:dejavu) { Krill.formatter("DejaVuSans.ttf") }

  let(:arranger) do
    Krill::Arranger.new.tap do |a|
      a.format_array = [
        { text: "hello\nworld\n\n\nhow are you?", font: font },
        { text: "\n", font: font },
        { text: "\n", font: font },
        { text: '', font: font },
        { text: 'fine, thanks. ' * 4, font: font },
        { text: '', font: font },
        { text: "\n", font: font },
        { text: '', font: font }
      ]
    end
  end
  let(:line_wrap) { described_class.new }

  it 'should only return an empty string if nothing fit or there' \
     'was nothing to wrap' do
    8.times do
      line = line_wrap.wrap_line(arranger: arranger, width: 200)
      expect(line).to_not be_empty
    end
    line = line_wrap.wrap_line(arranger: arranger, width: 200)
    expect(line).to be_empty
  end

  it 'tokenizes a string using the scan_pattern' do
    tokens = line_wrap.tokenize('one two three')
    expect(tokens.length).to eq(5)
  end

  describe 'LineWrap#wrap_line' do
    let(:arranger) { Krill::Arranger.new }
    let(:one_word_width) { 45 }

    it 'strips trailing spaces' do
      array = [
        { text: ' hello world, ', font: Krill.formatter("Helvetica.afm") },
        { text: 'goodbye  ', font: Krill.formatter("Helvetica-Bold.afm") }
      ]
      arranger.format_array = array
      string = line_wrap.wrap_line(arranger: arranger, width: 300)
      expect(string).to eq(' hello world, goodbye')
    end

    it 'should strip trailing spaces when a white-space-only fragment was' \
      ' successfully pushed onto the end of a line but no other non-white' \
      ' space fragment fits after it' do
      array = [
        { text: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa ', font: Krill.formatter("Helvetica.afm") },
        { text: '  ', font: Krill.formatter("Helvetica-Bold.afm") },
        { text: ' bbbbbbbbbbbbbbbbbbbbbbbbbbbb', font: Krill.formatter("Helvetica.afm") }
      ]
      arranger.format_array = array
      string = line_wrap.wrap_line(arranger: arranger, width: 300)
      expect(string).to eq('aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa')
    end

    it 'raise_errors CannotFit if a too-small width is given' do
      array = [
        { text: ' hello world, ', font: Krill.formatter("Helvetica.afm") },
        { text: 'goodbye  ', font: Krill.formatter("Helvetica-Bold.afm") }
      ]
      arranger.format_array = array
      expect do
        line_wrap.wrap_line(arranger: arranger, width: 1)
      end.to raise_error(Krill::CannotFit)
    end

    it 'breaks on space' do
      array = [{ text: 'hello world', font: font }]
      arranger.format_array = array
      string = line_wrap.wrap_line(arranger: arranger, width: one_word_width)
      expect(string).to eq('hello')
    end

    it 'breaks on zero-width space' do
      array = [{ text: "hello#{Krill::ZWSP}world", font: dejavu }]
      arranger.format_array = array
      string = line_wrap.wrap_line(arranger: arranger, width: one_word_width)
      expect(string).to eq('hello')
    end

    it 'does not display zero-width space' do
      array = [{ text: "hello#{Krill::ZWSP}world", font: dejavu }]
      arranger.format_array = array
      string = line_wrap.wrap_line(arranger: arranger, width: 300)
      expect(string).to eq('helloworld')
    end

    it 'does not raise CannotFit if first fragment is a zero-width space', :unresolved do
      array = [
        { text: Krill::ZWSP, font: dejavu },
        { text: 'stringofchars', font: dejavu }
      ]
      arranger.format_array = array
      string = line_wrap.wrap_line(arranger: arranger, width: 50)
      expect(string).to eq('stringof')
    end

    it 'breaks on tab' do
      array = [{ text: "hello\tworld", font: font }]
      arranger.format_array = array
      string = line_wrap.wrap_line(arranger: arranger, width: one_word_width)
      expect(string).to eq('hello')
    end

    it 'does not break on NBSP' do
      array = [{ text: "hello#{Krill::NBSP}world", font: font }]
      arranger.format_array = array
      string = line_wrap.wrap_line(arranger: arranger, width: one_word_width)
      expect(string).to eq("hello#{Krill::NBSP}wor")
    end

    it 'does not break on NBSP in a Win-1252 encoded string', :unresolved do
      array = [{ text: "hello#{Krill::NBSP}world".encode(Encoding::Windows_1252), font: font }]
      arranger.format_array = array
      string = line_wrap.wrap_line(arranger: arranger, width: one_word_width)
      expect(string).to eq("hello#{Krill::NBSP}wor")
    end

    it 'breaks on hyphens' do
      array = [{ text: 'hello-world', font: font }]
      arranger.format_array = array
      string = line_wrap.wrap_line(arranger: arranger, width: one_word_width)
      expect(string).to eq('hello-')
    end

    it 'should not break after a hyphen that follows white space and' \
      'precedes a word' do
      array = [{ text: 'hello -', font: font }]
      arranger.format_array = array
      string = line_wrap.wrap_line(arranger: arranger, width: one_word_width)
      expect(string).to eq('hello -')

      array = [{ text: 'hello -world', font: font }]
      arranger.format_array = array
      string = line_wrap.wrap_line(arranger: arranger, width: one_word_width)
      expect(string).to eq('hello')
    end

    it 'breaks on a soft hyphen' do
      string = font.normalize_encoding("hello#{Krill::SHY}world")
      array = [{ text: string, font: font }]
      arranger.format_array = array
      string = line_wrap.wrap_line(arranger: arranger, width: one_word_width)
      expect(string).to eq("hello#{Krill::SHY}")

      line_wrap = described_class.new

      string = "hello#{Krill::SHY}world"
      array = [{ text: string, font: dejavu }]
      arranger.format_array = array
      string = line_wrap.wrap_line(arranger: arranger, width: one_word_width)
      expect(string).to eq("hello#{Krill::SHY}")
    end

    it 'ignores width of a soft-hyphen during adding fragments to line',
      issue: 775 do
      hyphen_string = "Hy#{Krill::SHY}phe#{Krill::SHY}nat"\
        "#{Krill::SHY}ions "
      string1 = font.normalize_encoding(hyphen_string * 5)
      string2 = font.normalize_encoding('Hyphenations ' * 3 + hyphen_string)

      array1 = [{ text: string1, font: font }]
      array2 = [{ text: string2, font: font }]

      arranger.format_array = array1

      res1 = line_wrap.wrap_line(arranger: arranger, width: 300)

      line_wrap = described_class.new

      arranger.format_array = array2

      res2 = line_wrap.wrap_line(arranger: arranger, width: 300)
      expect(res1).to eq(res2)
    end

    it 'should not display soft hyphens except at the end of a line ' \
      'for more than one element in format_array', issue: 347 do
      line_wrap = described_class.new

      string1 = font.normalize_encoding("hello#{Krill::SHY}world ")
      string2 = font.normalize_encoding("hi#{Krill::SHY}earth")
      array = [{ text: string1, font: dejavu }, { text: string2, font: dejavu }]
      arranger.format_array = array
      string = line_wrap.wrap_line(arranger: arranger, width: 300)
      expect(string).to eq('helloworld hiearth')
    end

    it 'does not break before a hard hyphen that follows a word' do
      enough_width_for_hello_world = 60

      array = [{ text: 'hello world', font: font }]
      arranger.format_array = array
      string = line_wrap.wrap_line(arranger: arranger, width: enough_width_for_hello_world)
      expect(string).to eq('hello world')

      array = [{ text: 'hello world-', font: font }]
      arranger.format_array = array
      string = line_wrap.wrap_line(arranger: arranger, width: enough_width_for_hello_world)
      expect(string).to eq('hello')

      line_wrap = described_class.new
      enough_width_for_hello_world = 68

      array = [{ text: 'hello world', font: dejavu }]
      arranger.format_array = array
      string = line_wrap.wrap_line(arranger: arranger, width: enough_width_for_hello_world)
      expect(string).to eq('hello world')

      array = [{ text: 'hello world-', font: dejavu }]
      arranger.format_array = array
      string = line_wrap.wrap_line(arranger: arranger, width: enough_width_for_hello_world)
      expect(string).to eq('hello')
    end

    it 'should not break after a hard hyphen that follows a soft hyphen and' \
      'precedes a word' do
      string = font.normalize_encoding("hello#{Krill::SHY}-")
      array = [{ text: string, font: font }]
      arranger.format_array = array
      string = line_wrap.wrap_line(arranger: arranger, width: one_word_width)
      expect(string).to eq('hello-')

      string = font.normalize_encoding("hello#{Krill::SHY}-world")
      array = [{ text: string, font: font }]
      arranger.format_array = array
      string = line_wrap.wrap_line(arranger: arranger, width: one_word_width)
      expect(string).to eq("hello#{Krill::SHY}")

      line_wrap = described_class.new

      string = "hello#{Krill::SHY}-"
      array = [{ text: string, font: dejavu }]
      arranger.format_array = array
      string = line_wrap.wrap_line(arranger: arranger, width: one_word_width)
      expect(string).to eq('hello-')

      string = "hello#{Krill::SHY}-world"
      array = [{ text: string, font: dejavu }]
      arranger.format_array = array
      string = line_wrap.wrap_line(arranger: arranger, width: one_word_width)
      expect(string).to eq("hello#{Krill::SHY}")
    end

    it 'does not process UTF-8 chars with default font', :unresolved, issue: 693 do
      pending "Allow only Windows_1252 encoding on AFM fonts"
      array = [{ text: 'Ｔｅｓｔ', font: font }]
      arranger.format_array = array

      expect do
        line_wrap.wrap_line(arranger: arranger, width: 300)
      end.to raise_exception(Krill::IncompatibleStringEncoding)
    end

    it 'processes UTF-8 chars with UTF-8 font', issue: 693 do
      array = [{ text: 'Ｔｅｓｔ', font: dejavu }]
      arranger.format_array = array

      string = line_wrap.wrap_line(arranger: arranger, width: 300)

      expect(string).to eq('Ｔｅｓｔ')
    end
  end

  describe '#space_count' do
    let(:arranger) { Krill::Arranger.new }

    it 'returns the number of spaces in the last wrapped line' do
      array = [
        { text: 'hello world, ', font: Krill.formatter("Helvetica.afm") },
        { text: 'goodbye', font: Krill.formatter("Helvetica-Bold.afm") }
      ]
      arranger.format_array = array
      line_wrap.wrap_line(arranger: arranger, width: 300)
      expect(line_wrap.space_count).to eq(2)
    end

    it 'excludes trailing spaces from the count' do
      array = [
        { text: 'hello world, ', font: Krill.formatter("Helvetica.afm") },
        { text: 'goodbye  ', font: Krill.formatter("Helvetica-Bold.afm") }
      ]
      arranger.format_array = array
      line_wrap.wrap_line(arranger: arranger, width: 300)
      expect(line_wrap.space_count).to eq(2)
    end
  end

  describe '#paragraph_finished?' do
    let(:arranger) { Krill::Arranger.new }
    let(:line_wrap) { described_class.new }
    let(:one_word_width) { 50 }

    it 'is false when the last printed line is not the end of the paragraph' do
      array = [{ text: 'hello world', font: font }]
      arranger.format_array = array
      line_wrap.wrap_line(arranger: arranger, width: one_word_width)

      expect(line_wrap.paragraph_finished?).to eq(false)
    end

    it 'is true when the last printed line is the last fragment to print' do
      array = [{ text: 'hello world', font: font }]
      arranger.format_array = array
      line_wrap.wrap_line(arranger: arranger, width: one_word_width)
      line_wrap.wrap_line(arranger: arranger, width: one_word_width)

      expect(line_wrap.paragraph_finished?).to eq(true)
    end

    it 'be_trues when a newline exists on the current line' do
      array = [{ text: "hello\n world", font: font }]
      arranger.format_array = array
      line_wrap.wrap_line(arranger: arranger, width: one_word_width)

      expect(line_wrap.paragraph_finished?).to eq(true)
    end

    it 'be_trues when a newline exists in the next fragment' do
      array = [
        { text: 'hello ', font: font },
        { text: " \n", font: font },
        { text: 'world', font: font }
      ]
      arranger.format_array = array
      line_wrap.wrap_line(arranger: arranger, width: one_word_width)

      expect(line_wrap.paragraph_finished?).to eq(true)
    end
  end
end
