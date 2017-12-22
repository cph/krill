require "bundler"
Bundler.setup

require "pry"

if ENV["COVERAGE"]
  require "simplecov"
  SimpleCov.start do
    add_filter "/spec/"
  end
end

require_relative "../lib/krill"
require_relative "../lib/krill/ttf"
require_relative "../lib/krill/afm"

require "rspec"
require "pathname"

module Krill
  def self.font(name="Helvetica.afm")
    fonts[name]
  end

  def self.fonts
    @fonts ||= Hash.new do |fonts, name|
      fonts[name] = case File.extname(name)
                    when ".ttf" then Krill::TTF.open(DATADIR.join(name))
                    when ".afm" then Krill::AFM.open(DATADIR.join(name))
                    end
    end
  end

  def self.formatter(name="Helvetica.afm", size: 12, character_spacing: 0)
    Krill::Formatter.new(font(name), size, character_spacing: character_spacing)
  end

  DATADIR = Pathname.new(File.dirname(__FILE__)).join("data")
end
