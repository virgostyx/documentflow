# frozen_string_literal: true

require "rails_helper"

RSpec.describe ReferenceNumber do
  describe "#to_s" do
    it "formats as YYYY/#####" do
      reference = described_class.new(year: 2026, sequence: 5)
      expect(reference.to_s).to eq("2026/00005")
    end

    it "pads the sequence to five digits" do
      reference = described_class.new(year: 2026, sequence: 123)
      expect(reference.to_s).to eq("2026/00123")
    end
  end

  describe ".parse" do
    it "parses a valid reference number string" do
      reference = described_class.parse("2026/00042")
      expect(reference.year).to eq(2026)
      expect(reference.sequence).to eq(42)
    end

    it "returns nil for an invalid format" do
      expect(described_class.parse("not-a-reference")).to be_nil
      expect(described_class.parse("2026-00042")).to be_nil
      expect(described_class.parse(nil)).to be_nil
    end
  end

  describe ".first_for" do
    it "builds the first reference number of a given year" do
      reference = described_class.first_for(2026)
      expect(reference.to_s).to eq("2026/00001")
    end
  end

  describe "#next" do
    it "increments the sequence within the same year" do
      reference = described_class.new(year: 2026, sequence: 1)
      expect(reference.next.to_s).to eq("2026/00002")
    end

    it "does not mutate the original reference number" do
      reference = described_class.new(year: 2026, sequence: 1)
      reference.next
      expect(reference.to_s).to eq("2026/00001")
    end
  end

  describe "#==" do
    it "considers two reference numbers with the same year and sequence equal" do
      expect(described_class.new(year: 2026, sequence: 1)).to eq(described_class.new(year: 2026, sequence: 1))
    end

    it "considers reference numbers with different sequences not equal" do
      expect(described_class.new(year: 2026, sequence: 1)).not_to eq(described_class.new(year: 2026, sequence: 2))
    end
  end
end
