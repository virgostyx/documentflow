# frozen_string_literal: true

class PdfConversionJob < ApplicationJob
  queue_as :default

  def perform(document_id)
    document = Document.find(document_id)
    files_to_convert = document.files.reject { |file| file.content_type == "application/pdf" }

    files_to_convert.each { |file| convert_and_attach(document, file) }
  end

  private

  def convert_and_attach(document, file)
    file.open do |temp_file|
      pdf_path = PdfConverter.convert(temp_file.path)

      File.open(pdf_path) do |pdf_file|
        document.files.attach(io: pdf_file, filename: "#{file.filename.base}.pdf", content_type: "application/pdf")
      end

      File.delete(pdf_path) if File.exist?(pdf_path)
    end
  end
end
