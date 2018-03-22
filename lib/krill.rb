require "krill/version"
require "krill/text_box"
require "krill/wrapped_text"
require "krill/formatter"

module Krill

  def self.wrap_text(runs, width:, leading:)
    box = Krill::TextBox.new(runs, width: width, leading: leading, height: Float::INFINITY)
    box.render
    Krill::WrappedText.new(box)
  end

  CannotFit = Class.new(StandardError)

  # No-Break Space
  NBSP = " ".freeze

  # Zero Width Space (indicate word boundaries without a space)
  ZWSP = [8203].pack("U").freeze

  # Soft Hyphen (invisible, except when causing a line break)
  SHY = "­".freeze

end
