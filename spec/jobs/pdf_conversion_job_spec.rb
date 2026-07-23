# frozen_string_literal: true

require "rails_helper"

RSpec.describe PdfConversionJob do
  let(:document) { create(:document) }

  describe "#perform" do
    it "does nothing when no files are attached" do
      expect { described_class.new.perform(document.id) }.not_to raise_error
    end

    context "main document" do
      it "stamps the main file when it is already a PDF, without converting it" do
        document.main_file.attach(io: StringIO.new("%PDF-1.4 content"), filename: "report.pdf", content_type: "application/pdf")

        stamped_path = Rails.root.join("tmp", "report-stamped-#{SecureRandom.hex(4)}.pdf").to_s
        File.write(stamped_path, "%PDF-1.4 stamped content")

        expect(PdfConverter).not_to receive(:convert)
        expect(PdfStamper).to receive(:stamp).with(anything, document).and_return(stamped_path)

        described_class.new.perform(document.id)
        document.reload

        expect(document.main_file.content_type).to eq("application/pdf")
        expect(File.exist?(stamped_path)).to be(false)
      end

      it "converts a non-PDF main file, stamps it, replaces it with the resulting PDF and cleans up the temporary files" do
        document.main_file.attach(io: StringIO.new("plain text content"), filename: "notes.txt", content_type: "text/plain")

        converted_path = Rails.root.join("tmp", "notes-#{SecureRandom.hex(4)}.pdf").to_s
        File.write(converted_path, "%PDF-1.4 converted content")
        stamped_path = Rails.root.join("tmp", "notes-stamped-#{SecureRandom.hex(4)}.pdf").to_s
        File.write(stamped_path, "%PDF-1.4 stamped content")

        allow(PdfConverter).to receive(:convert).and_return(converted_path)
        expect(PdfStamper).to receive(:stamp).with(converted_path, document).and_return(stamped_path)

        described_class.new.perform(document.id)
        document.reload

        expect(document.main_file.filename.to_s).to eq("notes.pdf")
        expect(document.main_file.content_type).to eq("application/pdf")
        expect(File.exist?(converted_path)).to be(false)
        expect(File.exist?(stamped_path)).to be(false)
      end
    end

    context "annexes" do
      it "skips annexes that are already PDFs" do
        annex = create(:annex, document: document)
        annex.file.attach(io: StringIO.new("%PDF-1.4 content"), filename: "report.pdf", content_type: "application/pdf")

        expect(PdfConverter).not_to receive(:convert)
        expect(PdfStamper).not_to receive(:stamp)

        described_class.new.perform(document.id)
      end

      it "converts a non-PDF annex, replaces it with the resulting PDF in place, without stamping it" do
        annex = create(:annex, document: document)
        annex.file.attach(io: StringIO.new("plain text content"), filename: "notes.txt", content_type: "text/plain")

        converted_path = Rails.root.join("tmp", "notes-#{SecureRandom.hex(4)}.pdf").to_s
        File.write(converted_path, "%PDF-1.4 converted content")

        allow(PdfConverter).to receive(:convert).and_return(converted_path)
        expect(PdfStamper).not_to receive(:stamp)

        expect do
          described_class.new.perform(document.id)
        end.not_to change { document.annexes.count }

        annex.reload
        expect(annex.file.filename.to_s).to eq("notes.pdf")
        expect(annex.file.content_type).to eq("application/pdf")
        expect(File.exist?(converted_path)).to be(false)
      end
    end
  end
end
