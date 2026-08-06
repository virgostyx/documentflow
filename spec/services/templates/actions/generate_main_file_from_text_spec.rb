# frozen_string_literal: true

require "rails_helper"

RSpec.describe Templates::Actions::GenerateMainFileFromText do
  let(:document) { create(:document, subject: "VAT exemption request - Acme Corp") }
  let(:rendered_body) { "Please exempt the purchase from Acme Corp for an amount of 1200 EUR." }

  let(:ctx) { LightService::Context.make(document: document, rendered_body: rendered_body) }

  describe ".execute" do
    it "attaches a generated PDF as the document's main_file" do
      described_class.execute(ctx)

      expect(document.main_file).to be_attached
      expect(document.main_file.content_type).to eq("application/pdf")
    end

    it "succeeds" do
      result = described_class.execute(ctx)
      expect(result).to be_success
    end
  end
end
