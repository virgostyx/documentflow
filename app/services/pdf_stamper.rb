# frozen_string_literal: true

class PdfStamper
  # Raised when a signature image can't be embedded for an approved SIGN
  # step. Deliberately NOT rescued here (unlike the cosmetic reference/logo
  # stamp below): a document must never end up "signed" with no visible
  # signature, so this propagates out of the async PdfConversionJob and fails
  # the Solid Queue job (retryable) instead of silently degrading.
  class SignatureStampingError < StandardError; end

  MARGIN = 20
  LOGO_SIZE = 24
  SIGNATURE_HEIGHT = 60
  SIGNATURE_BLOCK_SPACING = 8
  FONT_SIZE = 8

  class << self
    # Draws the header (logo + reference number) and any signature blocks in
    # a single Prawn::Document/template pass. This matters beyond tidiness:
    # each Prawn::Document has its own image-label counter (I1, I2, ...), and
    # a page's label->XObject mapping is a plain hash that silently overwrites
    # on collision. Two independently-templated passes (one for the header,
    # a second re-templating the first pass's output for signatures) can
    # therefore reuse the same label on the same page and clobber the logo's
    # XObject with a signer's - a single shared counter makes that
    # structurally impossible.
    def stamp(pdf_path, document)
      signers = document.workflow_steps.where(role: "SIGN", status: "approved").order(:order, :id).includes(:actor)
      output_path = "#{pdf_path.sub(/\.pdf\z/i, '')}-stamped.pdf"
      logo_path = rasterized_logo_path(document)

      pdf = Prawn::Document.new(template: pdf_path)
      (1..pdf.page_count).each do |page_number|
        pdf.go_to_page(page_number)
        draw_stamp(pdf, document.reference_number, logo_path)
      end

      if signers.any?
        stamp_signatures_and_render(pdf, signers, output_path, pdf_path)
      else
        pdf.render_file(output_path)
      end

      output_path
    rescue SignatureStampingError
      raise
    rescue StandardError => e
      Rails.logger.warn("PdfStamper: failed to stamp #{pdf_path} (#{e.class}: #{e.message})")
      pdf_path
    ensure
      logo_path&.unlink if logo_path.respond_to?(:unlink)
    end

    private

    def stamp_signatures_and_render(pdf, signers, output_path, pdf_path)
      pdf.go_to_page(pdf.page_count)

      signers.each_with_index do |step, index|
        signature_image = step.actor.signature_image
        unless signature_image
          raise SignatureStampingError, "WorkflowStep##{step.id}: actor has no registered signature image"
        end

        draw_signature_block(pdf, step, signature_image, index)
      end

      pdf.render_file(output_path)
    rescue SignatureStampingError
      raise
    rescue StandardError => e
      raise SignatureStampingError, "Failed to stamp signature(s) onto #{pdf_path}: #{e.message}"
    end

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

    # Draws one signer's decrypted signature image + name/date block on the
    # already-open, already-on-the-last-page pdf, stacked one block per
    # signer (the common case is a single signer; a parallel SIGN group just
    # repeats the block). Bytes are decrypted straight into an in-memory
    # StringIO and never written to disk.
    def draw_signature_block(pdf, step, signature_image, index)
      block_height = SIGNATURE_HEIGHT + (FONT_SIZE * 2) + SIGNATURE_BLOCK_SPACING
      bottom = MARGIN + (index * (block_height + SIGNATURE_BLOCK_SPACING))

      pdf.canvas do
        pdf.image StringIO.new(signature_image.decoded_bytes), at: [ MARGIN, bottom + SIGNATURE_HEIGHT ], height: SIGNATURE_HEIGHT
        pdf.draw_text step.actor.full_name, at: [ MARGIN, bottom ], size: FONT_SIZE
        pdf.draw_text "Signed #{step.updated_at.strftime('%Y-%m-%d %H:%M')}", at: [ MARGIN, bottom - FONT_SIZE - 2 ], size: FONT_SIZE
      end
    end
  end
end
