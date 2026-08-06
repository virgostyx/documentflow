# frozen_string_literal: true

module Templates
  # Renders plain text to a PDF-attachable hash (io/filename/content_type),
  # for use as a Document's main_file. Mirrors EmailArchive::RenderBodyToPdf's
  # plain-text fallback: wraps the text in minimal HTML and converts via
  # PdfConverter (LibreOffice).
  class RenderTextToPdf
    class << self
      def call(text, filename: "document.pdf")
        Dir.mktmpdir do |dir|
          html_path = File.join(dir, "body.html")
          File.write(html_path, "<html><body><pre>#{ERB::Util.html_escape(text)}</pre></body></html>")

          pdf_path = PdfConverter.convert(html_path)
          { io: StringIO.new(File.binread(pdf_path)), filename: filename, content_type: "application/pdf" }
        end
      end
    end
  end
end
