# frozen_string_literal: true

require "rails_helper"

RSpec.describe Templates::TagScanner do
  describe ".tags_in" do
    it "extracts tag names from {{tag}} placeholders" do
      expect(described_class.tags_in("Hello {{name}}, your {{deadline}} is near")).to contain_exactly("name", "deadline")
    end

    it "deduplicates repeated tags" do
      expect(described_class.tags_in("{{name}} and {{name}} again")).to eq([ "name" ])
    end

    it "returns an empty array when there are no tags" do
      expect(described_class.tags_in("No placeholders here")).to eq([])
    end

    it "returns an empty array for nil input" do
      expect(described_class.tags_in(nil)).to eq([])
    end
  end
end
