# frozen_string_literal: true

require "rails_helper"

RSpec.describe PdfConversionJob do
  let(:document) { create(:document) }

  describe "#perform" do
    it "does nothing when the document has no files attached" do
      expect { described_class.new.perform(document.id) }.not_to raise_error
    end

    it "skips files that are already PDFs" do
      document.files.attach(io: StringIO.new("%PDF-1.4 content"), filename: "report.pdf", content_type: "application/pdf")

      expect(PdfConverter).not_to receive(:convert)

      described_class.new.perform(document.id)
    end

    it "converts non-PDF files, attaches the resulting PDF and cleans up the temporary file" do
      document.files.attach(io: StringIO.new("plain text content"), filename: "notes.txt", content_type: "text/plain")

      converted_path = Rails.root.join("tmp", "notes-#{SecureRandom.hex(4)}.pdf").to_s
      File.write(converted_path, "%PDF-1.4 converted content")

      allow(PdfConverter).to receive(:convert).and_return(converted_path)

      expect do
        described_class.new.perform(document.id)
        document.reload
      end.to change { document.files.count }.by(1)

      converted_attachment = document.files.find { |file| file.content_type == "application/pdf" }
      expect(converted_attachment.filename.to_s).to eq("notes.pdf")
      expect(File.exist?(converted_path)).to be(false)
    end
  end
end
