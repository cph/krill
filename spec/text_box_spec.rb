require 'spec_helper'

describe Krill::TextBox do
  let(:font) { Krill.formatter }

  describe 'wrapping' do
    it 'does not wrap between two fragments' do
      texts = [
        { text: 'Hello ', font: font },
        { text: 'World', font: font },
        { text: '2', font: font }
      ]
      text_box = described_class.new(texts, width: font.width_of('Hello World'))
      text_box.render
      expect(text_box.text).to eq("Hello\nWorld2")
    end

    it 'does not raise an Encoding::CompatibilityError when keeping a TTF and an AFM font together' do
      texts = [
        { text: 'Hello ', font: font },
        { text: '再见', font: Krill.formatter("gkai00mp.ttf") },
        { text: 'World', font: font }
      ]
      text_box = described_class.new(texts, width: font.width_of('Hello World'))

      text_box.render
    end

    it 'wraps between two fragments when the preceding fragment ends with a white space' do
      texts = [
        { text: 'Hello ', font: font },
        { text: 'World ', font: font },
        { text: '2', font: font }
      ]
      text_box = described_class.new(
        texts,
        width: font.width_of('Hello World') + 1
      )
      text_box.render
      expect(text_box.text).to eq("Hello World\n2")

      texts = [
        { text: 'Hello ', font: font },
        { text: "World\n", font: font },
        { text: '2', font: font }
      ]
      text_box = described_class.new(
        texts,
        width: font.width_of('Hello World') + 1
      )
      text_box.render
      expect(text_box.text).to eq("Hello World\n2")
    end

    it 'wraps between two fragments when the final fragment begins with a white space' do
      texts = [
        { text: 'Hello ', font: font },
        { text: 'World', font: font },
        { text: ' 2', font: font }
      ]
      text_box = described_class.new(
        texts,
        width: font.width_of('Hello World') + 1
      )
      text_box.render
      expect(text_box.text).to eq("Hello World\n2")

      texts = [
        { text: 'Hello ', font: font },
        { text: 'World', font: font },
        { text: "\n2", font: font }
      ]
      text_box = described_class.new(
        texts,
        width: font.width_of('Hello World') + 1
      )
      text_box.render
      expect(text_box.text).to eq("Hello World\n2")
    end

    it 'properlies handle empty slices using default encoding' do
      texts = [{
        text: 'Noua Delineatio Geographica generalis | Apostolicarum ' \
          'peregrinationum | S FRANCISCI XAUERII | Indiarum & Iaponiæ Apostoli',
        font: Krill.formatter("Courier.afm", size: 10)
      }]
      text_box = described_class.new(texts, width: font.width_of('Noua Delineatio Geographica gen'))
      expect do
        text_box.render
      end.to_not raise_error
      expect(text_box.text).to eq(
        "Noua Delineatio Geographica\ngeneralis | Apostolicarum\n" \
        "peregrinationum | S FRANCISCI\nXAUERII | Indiarum & Iaponiæ\n" \
        'Apostoli'
      )
    end
  end

  describe 'TextBox#render' do
    it 'handles newlines' do
      array = [{ text: "hello\nworld", font: font }]
      text_box = described_class.new(array, width: 612.0)
      text_box.render
      expect(text_box.text).to eq("hello\nworld")
    end

    it 'omits spaces from the beginning of the line' do
      array = [{ text: " hello\n world", font: font }]
      text_box = described_class.new(array, width: 612.0)
      text_box.render
      expect(text_box.text).to eq("hello\nworld")
    end

    it 'is okay printing a line of whitespace' do
      array = [{ text: "hello\n    \nworld", font: font }]
      text_box = described_class.new(array, width: 612.0)
      text_box.render
      expect(text_box.text).to eq("hello\n\nworld")

      array = [
        { text: 'hello' + ' ' * 500, font: font },
        { text: ' ' * 500, font: font },
        { text: ' ' * 500 + "\n", font: font },
        { text: 'world', font: font }
      ]
      text_box = described_class.new(array, width: 612.0)
      text_box.render
      expect(text_box.text).to eq("hello\n\nworld")
    end

    it 'enables fragment level direction setting', :unresolved do
      pending "Implement fragment-level direction setting"
      number_of_hellos = 18
      array = [
        { text: 'hello ' * number_of_hellos, font: font },
        { text: 'world', direction: :ltr, font: font },
        { text: ', how are you?', font: font }
      ]
      text_box = described_class.new(array, direction: :rtl, width: 612.0)
      text_box.render
      text = PDF::Inspector::Text.analyze(pdf.render)
      expect(text.strings[0]).to eq('era woh ,')
      expect(text.strings[1]).to eq('world')
      expect(text.strings[2]).to eq(' olleh' * number_of_hellos)
      expect(text.strings[3]).to eq('?uoy')
    end
  end

  describe 'TextBox#render' do
    it 'is able to set the font', :unresolved do
      pending "Test without PDF::Inspector"
      array = [
        { text: 'this contains ', font: font },
        { text: 'Times-Bold', font: Krill.font("Times-Bold.afm") },
        { text: ' text', font: font }
      ]
      text_box = described_class.new(array)
      text_box.render
      contents = PDF::Inspector::Text.analyze(pdf.render)
      fonts = contents.font_settings.map { |e| e[:name] }
      expect(fonts).to eq([:Helvetica, :"Times-Bold", :Helvetica])
      expect(contents.strings[0]).to eq('this contains ')
      expect(contents.strings[1]).to eq('Times-Bold')
      expect(contents.strings[2]).to eq(' text')
    end

    it 'is able to set subscript', :unresolved do
      pending "Implement superscript and subscript"
      array = [
        { text: 'this contains ' },
        { text: 'subscript', size: 18, styles: [:subscript] },
        { text: ' text' }
      ]
      text_box = described_class.new(array, width: 612.0)
      text_box.render
      contents = PDF::Inspector::Text.analyze(pdf.render)
      expect(contents.font_settings[0][:size]).to eq(12)
      expect(contents.font_settings[1][:size])
        .to be_within(0.0001).of(18 * 0.583)
    end

    it 'is able to set superscript', :unresolved do
      pending "Implement superscript and subscript"
      array = [
        { text: 'this contains ' },
        { text: 'superscript', size: 18, styles: [:superscript] },
        { text: ' text' }
      ]
      text_box = described_class.new(array, width: 612.0)
      text_box.render
      contents = PDF::Inspector::Text.analyze(pdf.render)
      expect(contents.font_settings[0][:size]).to eq(12)
      expect(contents.font_settings[1][:size])
        .to be_within(0.0001).of(18 * 0.583)
    end

    it 'is able to set font size', :unresolved do
      pending "Test without PDF::Inspector"
      array = [
        { text: 'this contains ' },
        { text: 'sized', size: 24 },
        { text: ' text' }
      ]
      text_box = described_class.new(array)
      text_box.render
      contents = PDF::Inspector::Text.analyze(pdf.render)
      expect(contents.font_settings[0][:size]).to eq(12)
      expect(contents.font_settings[1][:size]).to eq(24)
    end

    it 'sets the baseline based on the tallest fragment on a given line' do
      large_font = Krill.formatter(size: 24)
      array = [
        { text: 'this contains ', font: font },
        { text: 'sized', font: large_font },
        { text: ' text', font: font }
      ]
      text_box = described_class.new(array, width: 612.0)
      text_box.render
      expect(text_box.height).to be_within(0.001)
        .of(large_font.ascender + large_font.descender)
    end
  end

  describe 'TextBox#render with fragment level :character_spacing option' do
    it 'draws the character spacing to the document', :unresolved do
      pending "Test without PDF::Inspector"
      array = [{
        text: 'hello world',
        character_spacing: 7
      }]
      text_box = described_class.new(array)
      text_box.render
      contents = PDF::Inspector::Text.analyze(pdf.render)
      expect(contents.character_spacing[0]).to eq(7)
    end

    it 'lays out text properly' do
      array = [
        { text: 'hello world', font: Krill.formatter("Courier.afm", character_spacing: 10) }
      ]
      text_box = described_class.new(array, width: 100)
      text_box.render
      expect(text_box.text).to eq("hello\nworld")
    end
  end

  describe 'TextBox#render with :align => :justify' do
    it 'does not justify the last line of a paragraph', :unresolved do
      pending "Test without PDF::Inspector"
      array = [
        { text: 'hello world ', font: font },
        { text: "\n", font: font },
        { text: 'goodbye', font: font }
      ]
      text_box = described_class.new(array, options)
      text_box.render
      contents = PDF::Inspector::Text.analyze(pdf.render)
      expect(contents.word_spacing).to be_empty
    end
  end

end
