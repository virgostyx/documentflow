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

    context "with an approved SIGN step" do
      it "stamps the signer's image on the last page only" do
        document = create(:document, :finalized)
        signer = create(:user)
        create(:signature_image, user: signer)
        create(:workflow_step, :sign, :approved, document: document, actor: signer)
        pdf_path = build_pdf(pages: 2)

        output_path = described_class.stamp(pdf_path, document)

        reader = PDF::Reader.new(output_path)
        first_page_images = reader.pages[0].xobjects.values.count { |x| x.hash[:Subtype] == :Image }
        last_page_images = reader.pages[1].xobjects.values.count { |x| x.hash[:Subtype] == :Image }
        expect(first_page_images).to eq(0)
        expect(last_page_images).to eq(1)
        expect(reader.pages[1].text).to include(signer.full_name)
      end

      it "stacks a signature block per signer for a parallel SIGN group" do
        document = create(:document, :finalized)
        first_signer = create(:user)
        second_signer = create(:user)
        create(:signature_image, user: first_signer)
        create(:signature_image, user: second_signer)
        create(:workflow_step, :sign, :approved, :parallel, document: document, actor: first_signer, order: 1, parallel_group: 1)
        create(:workflow_step, :sign, :approved, :parallel, document: document, actor: second_signer, order: 2, parallel_group: 1)
        pdf_path = build_pdf(pages: 1)

        output_path = described_class.stamp(pdf_path, document)

        reader = PDF::Reader.new(output_path)
        image_count = reader.pages[0].xobjects.values.count { |x| x.hash[:Subtype] == :Image }
        expect(image_count).to eq(2)
      end

      it "orders stacked signature blocks by the SIGN step's circuit order, not database insertion order" do
        document = create(:document, :finalized)
        first_signer = create(:user, first_name: "Amelie", last_name: "Girard")
        second_signer = create(:user, first_name: "Baptiste", last_name: "Morel")
        create(:signature_image, user: first_signer)
        create(:signature_image, user: second_signer)

        # Inserted in reverse order relative to their circuit `order`, so a
        # query with no explicit ORDER BY could return them out of sequence.
        create(:workflow_step, :sign, :approved, document: document, actor: second_signer, order: 4)
        create(:workflow_step, :sign, :approved, document: document, actor: first_signer, order: 3)

        pdf_path = build_pdf(pages: 1)

        output_path = described_class.stamp(pdf_path, document)

        runs = PDF::Reader.new(output_path).pages[0].runs
        first_signer_y = runs.find { |r| r.text.include?(first_signer.full_name) }.y
        second_signer_y = runs.find { |r| r.text.include?(second_signer.full_name) }.y

        # Circuit order 3 (first_signer) must occupy stacking index 0, the
        # bottom-most block (lowest y); circuit order 4 (second_signer) must
        # be stacked above it.
        expect(first_signer_y).to be < second_signer_y
      end

      it "does not let the signature image overwrite the logo on a single-page document" do
        entity = create(:entity, :with_logo)
        department = create(:department, entity: entity)
        document = create(:document, :finalized, entity: entity, department: department)
        signer = create(:user)
        create(:signature_image, user: signer)
        create(:workflow_step, :sign, :approved, document: document, actor: signer)
        pdf_path = build_pdf(pages: 1)

        output_path = described_class.stamp(pdf_path, document)

        reader = PDF::Reader.new(output_path)
        image_count = reader.pages[0].xobjects.values.count { |x| x.hash[:Subtype] == :Image }
        expect(image_count).to eq(2)
      end

      it "does not let a stacked signature image overwrite the logo on the last page of a multi-page document" do
        entity = create(:entity, :with_logo)
        department = create(:department, entity: entity)
        document = create(:document, :finalized, entity: entity, department: department)
        first_signer = create(:user)
        second_signer = create(:user)
        create(:signature_image, user: first_signer)
        create(:signature_image, user: second_signer)
        create(:workflow_step, :sign, :approved, :parallel, document: document, actor: first_signer, order: 1, parallel_group: 1)
        create(:workflow_step, :sign, :approved, :parallel, document: document, actor: second_signer, order: 2, parallel_group: 1)
        pdf_path = build_pdf(pages: 2)

        output_path = described_class.stamp(pdf_path, document)

        reader = PDF::Reader.new(output_path)
        first_page_images = reader.pages[0].xobjects.values.count { |x| x.hash[:Subtype] == :Image }
        last_page_images = reader.pages[1].xobjects.values.count { |x| x.hash[:Subtype] == :Image }
        expect(first_page_images).to eq(1)
        expect(last_page_images).to eq(3)
      end

      it "raises instead of silently skipping when a signer has no registered signature image" do
        document = create(:document, :finalized)
        signer = create(:user)
        create(:workflow_step, :sign, :approved, document: document, actor: signer)
        pdf_path = build_pdf

        expect {
          described_class.stamp(pdf_path, document)
        }.to raise_error(PdfStamper::SignatureStampingError)
      end
    end
  end
end
