require 'spec_helper'

describe Krill::Fragment do
  let(:font) { Krill::formatter("DejaVuSans.ttf") }
  let(:format_state) {{ font: font }}

  describe 'Krill::Fragment' do
    let(:fragment) do
      described_class.new('hello world', format_state).tap do |fragment|
        fragment.width = 100
        fragment.left = 50
        fragment.baseline = 200
        fragment.line_height = 27
        fragment.descender = 7
        fragment.ascender = 17
      end
    end

    describe '#width' do
      it 'returns the width' do
        expect(fragment.width).to eq(100)
      end
    end

    describe '#line_height' do
      it 'returns the line_height' do
        expect(fragment.line_height).to eq(27)
      end
    end

    describe '#ascender' do
      it 'returns the ascender' do
        expect(fragment.ascender).to eq(17)
      end
    end

    describe '#descender' do
      it 'returns the descender' do
        expect(fragment.descender).to eq(7)
      end
    end

    describe '#y_offset' do
      it 'is zero' do
        expect(fragment.y_offset).to eq(0)
      end
    end

    describe '#underline_points' do
      it 'defines a line under the fragment' do
        y = 198.75
        target_points = [[50, y], [150, y]]
        expect(fragment.underline_points).to eq(target_points)
      end
    end

    describe '#strikethrough_points' do
      it 'defines a line through the fragment' do
        y = 200 + fragment.ascender * 0.3
        target_points = [[50, y], [150, y]]
        expect(fragment.strikethrough_points).to eq(target_points)
      end
    end
  end

  describe '#space_count' do
    it 'returns the number of spaces in the fragment' do
      fragment = described_class.new('hello world ', format_state)
      expect(fragment.space_count).to eq(2)
    end

    it 'should exclude trailing spaces from the count when ' \
      ':exclude_trailing_white_space => true' do
      format_state = { font: font, exclude_trailing_white_space: true }
      fragment = described_class.new('hello world ', format_state)
      expect(fragment.space_count).to eq(1)
    end
  end

  describe '#include_trailing_white_space!' do
    it 'makes the fragment include trailing white space' do
      format_state = { font: font, exclude_trailing_white_space: true }
      fragment = described_class.new('hello world ', format_state)
      expect(fragment.space_count).to eq(1)
      fragment.include_trailing_white_space!
      expect(fragment.space_count).to eq(2)
    end
  end

  describe '#text' do
    it 'returns the fragment text' do
      fragment = described_class.new('hello world ', format_state)
      expect(fragment.text).to eq('hello world ')
    end

    it 'should return the fragment text without trailing spaces when ' \
      ':exclude_trailing_white_space => true' do
      format_state = { font: font, exclude_trailing_white_space: true }
      fragment = described_class.new('hello world ', format_state)
      expect(fragment.text).to eq('hello world')
    end
  end

  describe '#word_spacing=' do
    let(:fragment) do
      described_class.new('hello world', format_state).tap do |fragment|
        fragment.width = 100
        fragment.left = 50
        fragment.baseline = 200
        fragment.line_height = 27
        fragment.descender = 7
        fragment.ascender = 17
        fragment.word_spacing = 10
      end
    end

    it 'accounts for word_spacing in #width' do
      expect(fragment.width).to eq(110)
    end

    it 'accounts for word_spacing in #underline_points' do
      y = 198.75
      target_points = [[50, y], [160, y]]
      expect(fragment.underline_points).to eq(target_points)
    end

    it 'accounts for word_spacing in #strikethrough_points' do
      y = 200 + fragment.ascender * 0.3
      target_points = [[50, y], [160, y]]
      expect(fragment.strikethrough_points).to eq(target_points)
    end
  end

  describe 'subscript' do
    let(:fragment) do
      font = Krill::formatter("DejaVuSans.ttf", subscript: true)
      format_state = { font: font }
      described_class.new('hello world', format_state).tap do |fragment|
        fragment.line_height = 27
        fragment.descender = 7
        fragment.ascender = 17
      end
    end

    describe '#subscript?' do
      it 'be_trues' do
        expect(fragment).to be_subscript
      end
    end

    describe '#y_offset' do
      it 'returns a negative value' do
        expect(fragment.y_offset).to be < 0
      end
    end
  end

  describe 'superscript' do
    let(:fragment) do
      font = Krill::formatter("DejaVuSans.ttf", superscript: true)
      format_state = { font: font }
      described_class.new('hello world', format_state).tap do |fragment|
        fragment.line_height = 27
        fragment.descender = 7
        fragment.ascender = 17
      end
    end

    describe '#superscript?' do
      it 'be_trues' do
        expect(fragment).to be_superscript
      end
    end

    describe '#y_offset' do
      it 'returns a positive value' do
        expect(fragment.y_offset).to be > 0
      end
    end
  end

  context 'with :direction => :rtl' do
    it '#text should be reversed' do
      format_state = { font: font, direction: :rtl }
      fragment = described_class.new('hello world', format_state)
      expect(fragment.text).to eq('dlrow olleh')
    end
  end

  describe '#default_direction=' do
    it 'should set the direction if there is no fragment level direction ' \
      'specification' do
      fragment = described_class.new('hello world', format_state)
      fragment.default_direction = :rtl
      expect(fragment.direction).to eq(:rtl)
    end

    it 'should not set the direction if there is a fragment level direction ' \
      'specification' do
      format_state = { font: font, direction: :rtl }
      fragment = described_class.new('hello world', format_state)
      fragment.default_direction = :ltr
      expect(fragment.direction).to eq(:rtl)
    end
  end
end
