# frozen_string_literal: true

class ReferenceNumber
  FORMAT = /\A([A-Z0-9]{1,8})\((\d{4})\)(\d{5})\z/

  attr_reader :prefix, :year, :sequence

  def self.parse(value)
    match = FORMAT.match(value.to_s)
    return nil unless match

    new(prefix: match[1], year: match[2].to_i, sequence: match[3].to_i)
  end

  def self.first_for(prefix:, year:)
    new(prefix: prefix, year: year, sequence: 1)
  end

  def initialize(prefix:, year:, sequence: 1)
    @prefix = prefix
    @year = year
    @sequence = sequence
  end

  def next
    self.class.new(prefix: prefix, year: year, sequence: sequence + 1)
  end

  def to_s
    format("%s(%04d)%05d", prefix, year, sequence)
  end

  def ==(other)
    other.is_a?(self.class) && prefix == other.prefix && year == other.year && sequence == other.sequence
  end
  alias eql? ==

  def hash
    [ prefix, year, sequence ].hash
  end
end
