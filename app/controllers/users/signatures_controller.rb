# frozen_string_literal: true

module Users
  # Self-service registration of the image stamped onto a document's PDF at
  # SIGN time (see PdfStamper). #show never renders the stored bytes back to
  # the browser - only metadata (content type, registration date).
  class SignaturesController < ApplicationController
    layout "pages"

    def show
      @signature_image = current_user.signature_image
    end

    def create
      file = params.dig(:signature_image, :file)
      return redirect_to signature_path, alert: "Please choose an image file." if file.blank?

      bytes = file.read
      signature_image = current_user.signature_image || current_user.build_signature_image
      signature_image.assign_attributes(
        image_data: Base64.strict_encode64(bytes),
        content_type: file.content_type,
        byte_size: bytes.bytesize
      )

      if signature_image.save
        redirect_to signature_path, notice: "Signature saved."
      else
        redirect_to signature_path, alert: signature_image.errors.full_messages.to_sentence
      end
    end

    def destroy
      current_user.signature_image&.destroy!
      redirect_to signature_path, notice: "Signature removed."
    end
  end
end
