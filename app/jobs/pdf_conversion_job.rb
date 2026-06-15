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
    return if main_file.content_type == "application/pdf"

    main_file.open do |temp_file|
      pdf_path = PdfConverter.convert(temp_file.path)

      File.open(pdf_path) do |pdf_file|
        document.main_file.attach(io: pdf_file, filename: "#{main_file.filename.base}.pdf", content_type: "application/pdf")
      end

      File.delete(pdf_path) if File.exist?(pdf_path)
    end
  end

  def convert_annexes(document)
    annexes_to_convert = document.annexes.reject { |annex| annex.content_type == "application/pdf" }

    annexes_to_convert.each { |annex| convert_and_attach_annex(document, annex) }
  end

  def convert_and_attach_annex(document, annex)
    annex.open do |temp_file|
      pdf_path = PdfConverter.convert(temp_file.path)

      File.open(pdf_path) do |pdf_file|
        document.annexes.attach(io: pdf_file, filename: "#{annex.filename.base}.pdf", content_type: "application/pdf")
      end

      File.delete(pdf_path) if File.exist?(pdf_path)
    end
  end
end
