# frozen_string_literal: true

class FilePreviewRenderer
  class << self
    def pdf_bytes_for(attached_file)
      return attached_file.download if attached_file.content_type == "application/pdf"

      attached_file.open do |temp_file|
        pdf_path = PdfConverter.convert(temp_file.path)
        bytes = File.binread(pdf_path)
        File.delete(pdf_path) if File.exist?(pdf_path)
        bytes
      end
    end
  end
end
