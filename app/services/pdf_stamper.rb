# frozen_string_literal: true

class PdfStamper
  MARGIN = 20
  LOGO_SIZE = 24
  FONT_SIZE = 8

  class << self
    def stamp(pdf_path, document)
      output_path = "#{pdf_path.sub(/\.pdf\z/i, '')}-stamped.pdf"
      logo_path = rasterized_logo_path(document)

      pdf = Prawn::Document.new(template: pdf_path)
      (1..pdf.page_count).each do |page_number|
        pdf.go_to_page(page_number)
        draw_stamp(pdf, document.reference_number, logo_path)
      end
      pdf.render_file(output_path)

      output_path
    rescue StandardError => e
      Rails.logger.warn("PdfStamper: failed to stamp #{pdf_path} (#{e.class}: #{e.message})")
      pdf_path
    ensure
      logo_path&.unlink if logo_path.respond_to?(:unlink)
    end

    private

    def draw_stamp(pdf, reference_number, logo_path)
      pdf.canvas do
        text_width = pdf.width_of(reference_number, size: FONT_SIZE)
        top = pdf.bounds.top - MARGIN
        right = pdf.bounds.right - MARGIN
        text_x = right - text_width

        if logo_path
          text_x -= (LOGO_SIZE + 4)
          pdf.image logo_path.path, at: [ text_x, top ], width: LOGO_SIZE, height: LOGO_SIZE
          text_x += LOGO_SIZE + 4
        end

        pdf.draw_text reference_number, at: [ text_x, top - (LOGO_SIZE / 2.0) - (FONT_SIZE / 2.0) ], size: FONT_SIZE
      end
    end

    def logo_attachment(document)
      department_logo = document.department&.logo
      return department_logo if department_logo&.attached?

      entity_logo = document.entity&.logo
      return entity_logo if entity_logo&.attached?

      nil
    end

    def rasterized_logo_path(document)
      attachment = logo_attachment(document)
      return nil unless attachment

      variant = attachment.variant(resize_to_limit: [ LOGO_SIZE * 4, LOGO_SIZE * 4 ], format: :png).processed

      tempfile = Tempfile.new([ "pdf_stamper_logo", ".png" ], binmode: true)
      tempfile.write(variant.download)
      tempfile.flush
      tempfile
    rescue StandardError => e
      Rails.logger.warn("PdfStamper: failed to rasterize logo for document #{document.id} (#{e.class}: #{e.message})")
      nil
    end
  end
end
