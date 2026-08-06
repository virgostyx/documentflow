# frozen_string_literal: true

require "rails_helper"

RSpec.describe Templates::Actions::GenerateMainFileFromDocx do
  let(:document) { create(:document, subject: "VAT exemption request - Acme Corp") }
  let(:document_template) do
    template = build(:document_template)
    attach_docx(template, :source_file, docx_paragraph("Please exempt {{supplier}} for {{amount}}."))
    template.save!
    template
  end
  let(:field_values) { { "supplier" => "Acme Corp", "amount" => "1200 EUR" } }

  let(:ctx) do
    LightService::Context.make(document: document, document_template: document_template, field_values: field_values)
  end

  describe ".execute" do
    it "attaches a .docx main_file with the tags substituted" do
      described_class.execute(ctx)

      expect(document.main_file).to be_attached
      expect(document.main_file.content_type).to eq(DocumentTemplate::DOCX_CONTENT_TYPE)

      document.main_file.open do |file|
        xml = Zip::File.open(file.path) { |zip| zip.read("word/document.xml") }
        expect(xml).to include("Please exempt Acme Corp for 1200 EUR.")
        expect(xml).not_to include("{{")
      end
    end

    it "keeps the template's original filename" do
      described_class.execute(ctx)
      expect(document.main_file.filename.to_s).to eq(document_template.source_file.filename.to_s)
    end

    it "succeeds" do
      result = described_class.execute(ctx)
      expect(result).to be_success
    end
  end
end
