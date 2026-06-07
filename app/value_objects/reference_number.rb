# frozen_string_literal: true

class ReferenceNumber
  FORMAT = /\A(\d{4})\/(\d{5})\z/

  attr_reader :year, :sequence

  def self.parse(value)
    match = FORMAT.match(value.to_s)
    return nil unless match

    new(year: match[1].to_i, sequence: match[2].to_i)
  end

  def self.first_for(year)
    new(year: year, sequence: 1)
  end

  def initialize(year:, sequence: 1)
    @year = year
    @sequence = sequence
  end

  def next
    self.class.new(year: year, sequence: sequence + 1)
  end

  def to_s
    format("%04d/%05d", year, sequence)
  end

  def ==(other)
    other.is_a?(self.class) && year == other.year && sequence == other.sequence
  end
  alias eql? ==

  def hash
    [ year, sequence ].hash
  end
end
