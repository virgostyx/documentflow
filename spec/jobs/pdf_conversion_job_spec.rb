# frozen_string_literal: true

require "rails_helper"

RSpec.describe PdfConversionJob do
  let(:document) { create(:document) }

  describe "#perform" do
    it "finds the document without raising" do
      expect { described_class.new.perform(document.id) }.not_to raise_error
    end
  end
end
