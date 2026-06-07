# frozen_string_literal: true

class PdfConversionJob < ApplicationJob
  queue_as :default

  def perform(document_id)
    document = Document.find(document_id)

    document.files.each do |file|
      next if file.content_type == "application/pdf"

      Rails.logger.info("[PDF_CONVERSION] Conversion to be implemented in Phase 5 | File: #{file.filename}")
    end
  end
end
