# frozen_string_literal: true

module EmailArchive
  # Renders a Mail::Message's body to a PDF-attachable hash (io/filename/
  # content_type), for use as a Document's main_file. Prefers the HTML part;
  # falls back to the plain-text part wrapped in minimal HTML.
  class RenderBodyToPdf
    class << self
      def call(message, filename: "email.pdf")
        Dir.mktmpdir do |dir|
          html_path = File.join(dir, "body.html")
          File.write(html_path, html_content_for(message))

          pdf_path = PdfConverter.convert(html_path)
          { io: StringIO.new(File.binread(pdf_path)), filename: filename, content_type: "application/pdf" }
        end
      end

      private

      def html_content_for(message)
        return message.html_part.decoded if message.html_part

        text = message.text_part&.decoded || message.body&.decoded || ""
        "<html><body><pre>#{ERB::Util.html_escape(text)}</pre></body></html>"
      end
    end
  end
end
