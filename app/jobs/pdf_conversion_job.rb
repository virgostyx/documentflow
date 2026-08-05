# frozen_string_literal: true

class PdfConversionJob < ApplicationJob
  queue_as :default

  retry_on StandardError, wait: :exponentially_longer, attempts: 3

  def perform(document_id, step_id = nil)
    document = Document.find(document_id)

    convert_main_file(document, step_id)
    convert_annexes(document)
  end

  private

  def convert_main_file(document, step_id)
    main_file = document.main_file
    return unless main_file.attached?

    already_pdf = main_file.content_type == "application/pdf"

    main_file.open do |temp_file|
      pdf_path = already_pdf ? temp_file.path : PdfConverter.convert(temp_file.path)
      stamped_path = PdfStamper.stamp(pdf_path, document)

      File.open(stamped_path) do |pdf_file|
        document.main_file.attach(io: pdf_file, filename: "#{main_file.filename.base}.pdf", content_type: "application/pdf")
      end

      log_signature_audit_event(document, stamped_path, step_id)

      File.delete(pdf_path) if !already_pdf && File.exist?(pdf_path)
      File.delete(stamped_path) if stamped_path != pdf_path && File.exist?(stamped_path)
    end
  end

  # One AuditLog for the SIGN step that triggered this run, recording the
  # SHA-256 of the exact bytes just attached as main_file - lets anyone later
  # verify a given PDF matches what was recorded at signing time. Scoped to
  # step_id (rather than all approved SIGN steps) because this job can run
  # more than once per document - once per completed SIGN stage - and the PDF
  # is re-stamped with every currently-approved signer each time; logging
  # every approved signer on every run would create duplicate audit rows for
  # signers already logged in an earlier run.
  def log_signature_audit_event(document, stamped_path, step_id)
    return if step_id.nil?

    step = document.workflow_steps.find_by(id: step_id, role: "SIGN", status: "approved")
    return unless step

    pdf_sha256 = Digest::SHA256.file(stamped_path).hexdigest

    AuditLog.log_event(
      user: step.actor,
      auditable: document,
      action: "sign_document",
      changes: { workflow_step_id: step.id, method: "webauthn_step_up", pdf_sha256: pdf_sha256, approved_at: step.updated_at.iso8601 },
      ip_address: step.ip_address,
      user_agent: step.user_agent
    )
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
