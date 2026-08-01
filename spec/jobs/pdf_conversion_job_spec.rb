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

    context "signature audit trail" do
      it "logs one AuditLog per approved SIGN step with the stamped PDF's SHA-256" do
        document.main_file.attach(io: StringIO.new("%PDF-1.4 content"), filename: "report.pdf", content_type: "application/pdf")
        signer = create(:user)
        step = create(:workflow_step, :sign, :approved, document: document, actor: signer)

        stamped_path = Rails.root.join("tmp", "report-stamped-#{SecureRandom.hex(4)}.pdf").to_s
        File.write(stamped_path, "%PDF-1.4 stamped content")
        allow(PdfStamper).to receive(:stamp).and_return(stamped_path)
        expected_sha256 = Digest::SHA256.hexdigest("%PDF-1.4 stamped content")

        expect {
          described_class.new.perform(document.id)
        }.to change(AuditLog, :count).by(1)

        log = AuditLog.last
        expect(log.user).to eq(signer)
        expect(log.auditable).to eq(document)
        expect(log.action).to eq("sign_document")
        expect(log.change_data["workflow_step_id"]).to eq(step.id)
        expect(log.change_data["pdf_sha256"]).to eq(expected_sha256)
      end

      it "logs nothing when the document has no approved SIGN step" do
        document.main_file.attach(io: StringIO.new("%PDF-1.4 content"), filename: "report.pdf", content_type: "application/pdf")

        stamped_path = Rails.root.join("tmp", "report-stamped-#{SecureRandom.hex(4)}.pdf").to_s
        File.write(stamped_path, "%PDF-1.4 stamped content")
        allow(PdfStamper).to receive(:stamp).and_return(stamped_path)

        expect { described_class.new.perform(document.id) }.not_to change(AuditLog, :count)
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
