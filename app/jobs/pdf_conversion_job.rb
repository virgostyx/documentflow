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

      File.delete(pdf_path) if !already_pdf && File.exist?(pdf_path)
      File.delete(stamped_path) if stamped_path != pdf_path && File.exist?(stamped_path)
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
