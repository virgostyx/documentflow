# frozen_string_literal: true

# Attaches a "logo" and validates its content type and size.
module HasValidatedLogo
  extend ActiveSupport::Concern

  LOGO_CONTENT_TYPES = %w[image/png image/jpeg image/svg+xml image/webp].freeze
  LOGO_MAX_SIZE = 1.megabyte

  included do
    has_one_attached :logo
    validate :logo_must_be_a_valid_image
  end

  private

  def logo_must_be_a_valid_image
    return unless logo.attached?

    unless logo.content_type.in?(LOGO_CONTENT_TYPES)
      errors.add(:logo, "must be a PNG, JPEG, SVG, or WebP image")
    end

    if logo.blob.byte_size > LOGO_MAX_SIZE
      errors.add(:logo, "must be smaller than #{LOGO_MAX_SIZE / 1.megabyte}MB")
    end
  end
end
