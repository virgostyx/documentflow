# frozen_string_literal: true

class PdfConversionJob < ApplicationJob
  queue_as :default

  def perform(document_id)
    document = Document.find(document_id)

    convert_main_file(document)
    convert_annexes(document)
  end

  private

  def convert_main_file(document)
    main_file = document.main_file
    return unless main_file.attached?

    already_pdf = main_file.content_type == "application/pdf"

    main_file.open do |temp_file|
      pdf_path = already_pdf ? temp_file.path : PdfConverter.convert(temp_file.path)
      stamped_path = PdfStamper.stamp(pdf_path, document)

      File.open(stamped_path) do |pdf_file|
        document.main_file.attach(io: pdf_file, filename: "#{main_file.filename.base}.pdf", content_type: "application/pdf")
      end

      log_signature_audit_events(document, stamped_path)

      File.delete(pdf_path) if !already_pdf && File.exist?(pdf_path)
      File.delete(stamped_path) if stamped_path != pdf_path && File.exist?(stamped_path)
    end
  end

  # One AuditLog per approved SIGN step, recording the SHA-256 of the exact
  # bytes just attached as main_file - lets anyone later verify a given PDF
  # matches what was recorded at signing time. No-ops for documents with no
  # SIGN steps (the common case for this job, e.g. re-conversion on upload).
  def log_signature_audit_events(document, stamped_path)
    signers = document.workflow_steps.where(role: "SIGN", status: "approved").includes(:actor)
    return if signers.none?

    pdf_sha256 = Digest::SHA256.file(stamped_path).hexdigest

    signers.each do |step|
      AuditLog.log_event(
        user: step.actor,
        auditable: document,
        action: "sign_document",
        changes: { workflow_step_id: step.id, method: "webauthn_step_up", pdf_sha256: pdf_sha256, approved_at: step.updated_at.iso8601 },
        ip_address: step.ip_address,
        user_agent: step.user_agent
      )
    end
  end

  def convert_annexes(document)
    document.annexes.each do |annex|
      next unless annex.file.attached?
      next if annex.file.content_type == "application/pdf"

      convert_and_replace_annex_file(annex)
    end
  end

  def convert_and_replace_annex_file(annex)
    original_basename = annex.file.filename.base

    annex.file.open do |temp_file|
      pdf_path = PdfConverter.convert(temp_file.path)

      File.open(pdf_path) do |pdf_file|
        annex.file.attach(io: pdf_file, filename: "#{original_basename}.pdf", content_type: "application/pdf")
      end

      File.delete(pdf_path) if File.exist?(pdf_path)
    end
  end
end
