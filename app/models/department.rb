# frozen_string_literal: true

class Department < ApplicationRecord
  belongs_to :entity
  has_many :entity_user_departments, dependent: :destroy
  has_many :entity_users, through: :entity_user_departments
  has_many :documents, dependent: :restrict_with_error
  has_many :document_templates, dependent: :nullify
  has_one_attached :logo

  LOGO_CONTENT_TYPES = %w[image/png image/jpeg image/svg+xml image/webp].freeze
  LOGO_MAX_SIZE = 1.megabyte

  validates :name, presence: true, uniqueness: { scope: :entity_id }
  validates :prefix, presence: true,
                      length: { maximum: 8 },
                      format: { with: /\A[A-Z0-9]+\z/, message: "must contain only uppercase letters and digits" },
                      uniqueness: { scope: :entity_id }
  validates :archive_ingestion_email, format: { with: URI::MailTo::EMAIL_REGEXP }, uniqueness: true, allow_blank: true
  validate :logo_must_be_a_valid_image

  before_validation :normalize_prefix
  before_validation :normalize_archive_ingestion_email

  scope :default, -> { where(is_default: true) }

  def default?
    is_default
  end

  private

  def normalize_prefix
    self.prefix = prefix.upcase if prefix.present?
  end

  def normalize_archive_ingestion_email
    self.archive_ingestion_email = archive_ingestion_email.strip.downcase if archive_ingestion_email.present?
  end

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
