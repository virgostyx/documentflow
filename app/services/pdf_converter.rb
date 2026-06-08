# frozen_string_literal: true

class PdfConverter
  class ConversionError < StandardError; end

  LIBREOFFICE_EXTENSIONS = %w[.docx .xlsx .pptx].freeze
  IMAGE_EXTENSIONS = %w[.jpg .jpeg .png].freeze

  class << self
    def convert(file_path)
      case File.extname(file_path).downcase
      when *LIBREOFFICE_EXTENSIONS then convert_with_libreoffice(file_path)
      when ".txt" then convert_with_prawn(file_path)
      when *IMAGE_EXTENSIONS then convert_image_to_pdf(file_path)
      when ".pdf" then file_path
      else raise ConversionError, "Unsupported format: #{File.extname(file_path)}"
      end
    end

    private

    def output_path_for(file_path)
      file_path.sub(/\.\w+\z/, ".pdf")
    end

    def convert_with_libreoffice(file_path)
      output_dir = File.dirname(file_path)

      # Pass each argument separately (array form of `system`) so they reach the
      # process directly, bypassing the shell entirely — a path containing shell
      # metacharacters can't be interpreted as a second command this way.
      success = system("soffice", "--headless", "--convert-to", "pdf", "--outdir", output_dir, file_path)
      raise ConversionError, "LibreOffice conversion failed for #{file_path}" unless success

      output_path_for(file_path)
    end

    def convert_with_prawn(file_path)
      output_path = output_path_for(file_path)
      Prawn::Document.generate(output_path) { |pdf| pdf.text File.read(file_path) }
      output_path
    end

    def convert_image_to_pdf(file_path)
      output_path = output_path_for(file_path)
      Prawn::Document.generate(output_path) { |pdf| pdf.image file_path, fit: [ 500, 700 ] }
      output_path
    end
  end
end
