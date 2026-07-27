# frozen_string_literal: true

require "rails_helper"
require "pdf/reader"

RSpec.describe PdfStamper do
  around do |example|
    Dir.mktmpdir do |dir|
      @tmp_dir = dir
      example.run
    end
  end

  def build_pdf(pages: 2)
    path = File.join(@tmp_dir, "source.pdf")
    Prawn::Document.generate(path) do |pdf|
      pages.times do |i|
        pdf.start_new_page unless i.zero?
        pdf.text "Page #{i + 1} content"
      end
    end
    path
  end

  def image_on_every_page?(pdf_path)
    PDF::Reader.new(pdf_path).pages.all? do |page|
      page.xobjects.values.any? { |xobject| xobject.hash[:Subtype] == :Image }
    end
  end

  describe ".stamp" do
    it "draws the document's reference number on every page" do
      pdf_path = build_pdf(pages: 3)
      document = create(:document, reference_number: "ENT(2026)00042")

      output_path = described_class.stamp(pdf_path, document)

      reader = PDF::Reader.new(output_path)
      expect(reader.page_count).to eq(3)
      reader.pages.each do |page|
        expect(page.text).to include("ENT(2026)00042")
      end
    end

    it "draws the department logo when the document's department has one" do
      entity = create(:entity)
      department = create(:department, :with_logo, entity: entity)
      document = create(:document, entity: entity, department: department, reference_number: "ENT(2026)00001")
      pdf_path = build_pdf

      output_path = described_class.stamp(pdf_path, document)

      expect(image_on_every_page?(output_path)).to be(true)
    end

    it "falls back to the entity logo when the department has none" do
      entity = create(:entity, :with_logo)
      department = create(:department, entity: entity)
      document = create(:document, entity: entity, department: department, reference_number: "ENT(2026)00001")
      pdf_path = build_pdf

      output_path = described_class.stamp(pdf_path, document)

      expect(image_on_every_page?(output_path)).to be(true)
    end

    it "draws a text-only stamp when neither the department nor the entity has a logo" do
      document = create(:document, :finalized)
      pdf_path = build_pdf

      output_path = described_class.stamp(pdf_path, document)

      expect(image_on_every_page?(output_path)).to be(false)
      expect(PDF::Reader.new(output_path).pages.first.text).to include(document.reference_number)
    end

    it "returns the original path unchanged if stamping fails" do
      pdf_path = build_pdf
      document = create(:document)

      allow(Prawn::Document).to receive(:new).and_raise(StandardError, "boom")

      expect(described_class.stamp(pdf_path, document)).to eq(pdf_path)
    end
  end
end
