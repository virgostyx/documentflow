# frozen_string_literal: true

module EmailArchive
  module Actions
    class AttachEmailContent < ApplicationAction
      expects :mail, :document

      executed do |ctx|
        ctx.document.main_file.attach(RenderBodyToPdf.call(ctx.mail))

        ctx.mail.attachments.each do |attachment|
          ctx.document.annexes.create!(file: attachment_hash_for(attachment))
        end
      end

      class << self
        # Best-effort: converts each real attachment to PDF like a normally
        # finalized document's annexes end up, but a single unconvertible
        # attachment shouldn't fail the whole ingestion — fall back to
        # attaching it as-is and log a warning.
        def attachment_hash_for(attachment)
          convert_to_pdf(attachment) || raw_hash_for(attachment)
        end

        def convert_to_pdf(attachment)
          Dir.mktmpdir do |dir|
            src = File.join(dir, attachment.filename.to_s.presence || "attachment")
            File.binwrite(src, attachment.body.decoded)
            pdf_path = PdfConverter.convert(src)
            { io: StringIO.new(File.binread(pdf_path)), filename: File.basename(pdf_path), content_type: "application/pdf" }
          end
        rescue PdfConverter::ConversionError, StandardError => e
          Rails.logger.warn("[EmailArchive::AttachEmailContent] could not convert #{attachment.filename}: #{e.message}")
          nil
        end

        def raw_hash_for(attachment)
          { io: StringIO.new(attachment.body.decoded), filename: attachment.filename.to_s.presence || "attachment", content_type: attachment.mime_type }
        end
      end
    end
  end
end
