# frozen_string_literal: true

class Department < ApplicationRecord
  belongs_to :entity
  has_many :entity_user_departments, dependent: :destroy
  has_many :entity_users, through: :entity_user_departments
  has_many :documents, dependent: :restrict_with_error
  has_one_attached :logo

  LOGO_CONTENT_TYPES = %w[image/png image/jpeg image/svg+xml image/webp].freeze
  LOGO_MAX_SIZE = 1.megabyte

  validates :name, presence: true, uniqueness: { scope: :entity_id }
  validate :logo_must_be_a_valid_image

  scope :default, -> { where(is_default: true) }

  def default?
    is_default
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
