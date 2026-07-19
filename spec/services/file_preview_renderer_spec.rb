# frozen_string_literal: true

require "rails_helper"

RSpec.describe FilePreviewRenderer do
  let(:document) { create(:document) }

  describe ".pdf_bytes_for" do
    context "when the attached file is already a PDF" do
      before do
        document.main_file.attach(io: StringIO.new("%PDF-1.4 content"), filename: "report.pdf", content_type: "application/pdf")
      end

      it "returns the file's bytes unchanged without converting" do
        expect(PdfConverter).not_to receive(:convert)

        expect(described_class.pdf_bytes_for(document.main_file)).to eq("%PDF-1.4 content")
      end
    end

    context "when the attached file is not a PDF" do
      before do
        document.main_file.attach(io: StringIO.new("plain text content"), filename: "notes.txt", content_type: "text/plain")
      end

      it "converts it and returns the resulting PDF bytes, without mutating the original attachment" do
        converted_path = Rails.root.join("tmp", "notes-#{SecureRandom.hex(4)}.pdf").to_s
        File.write(converted_path, "%PDF-1.4 converted content")
        allow(PdfConverter).to receive(:convert).and_return(converted_path)

        original_blob_id = document.main_file.blob.id

        bytes = described_class.pdf_bytes_for(document.main_file)

        expect(bytes).to eq("%PDF-1.4 converted content")
        expect(document.main_file.blob.id).to eq(original_blob_id)
        expect(document.main_file.content_type).to eq("text/plain")
      end

      it "deletes the temporary converted file after reading it" do
        converted_path = Rails.root.join("tmp", "notes-#{SecureRandom.hex(4)}.pdf").to_s
        File.write(converted_path, "%PDF-1.4 converted content")
        allow(PdfConverter).to receive(:convert).and_return(converted_path)

        described_class.pdf_bytes_for(document.main_file)

        expect(File.exist?(converted_path)).to be(false)
      end
    end
  end
end
