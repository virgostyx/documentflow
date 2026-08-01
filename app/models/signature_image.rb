# frozen_string_literal: true

# SECURITY: image_data holds a person's handwritten-signature image. It must
# never be exposed via any controller/view/API response. #decoded_bytes is
# meant for a single caller: PdfStamper, at the moment of stamping.
class SignatureImage < ApplicationRecord
  belongs_to :user

  encrypts :image_data

  CONTENT_TYPES = %w[image/png image/jpeg].freeze
  MAX_BYTE_SIZE = 2.megabytes

  validates :image_data, presence: true
  validates :content_type, presence: true, inclusion: { in: CONTENT_TYPES }
  validates :byte_size, presence: true,
                         numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: MAX_BYTE_SIZE }
  validates :user_id, uniqueness: true

  def decoded_bytes
    Base64.strict_decode64(image_data)
  end
end
