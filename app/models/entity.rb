# frozen_string_literal: true

class Entity < ApplicationRecord
  STATUSES = %w[active suspended cancelled].freeze

  # Associations
  has_many :entity_users, dependent: :destroy
  has_many :users, through: :entity_users
  has_many :contacts, dependent: :destroy
  has_many :documents, dependent: :destroy
  has_many :departments, dependent: :destroy
  has_many :classification_nodes, dependent: :destroy
  has_many :circuit_templates, dependent: :destroy
  has_many :document_templates, dependent: :destroy
  has_many :email_templates, dependent: :destroy
  has_one_attached :logo

  LOGO_CONTENT_TYPES = %w[image/png image/jpeg image/svg+xml image/webp].freeze
  LOGO_MAX_SIZE = 1.megabyte

  # Validations
  validates :name, presence: true, uniqueness: true
  validates :code, presence: true, uniqueness: true
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :acronym, length: { maximum: 10 }, allow_blank: true
  validates :prefix, presence: true,
                      length: { maximum: 8 },
                      format: { with: /\A[A-Z0-9]+\z/, message: "must contain only uppercase letters and digits" },
                      uniqueness: true
  validates :incoming_archive_email, format: { with: URI::MailTo::EMAIL_REGEXP }, uniqueness: true, allow_blank: true
  validate :logo_must_be_a_valid_image

  # Callbacks
  before_validation :generate_code, on: :create
  before_validation :normalize_prefix
  before_validation :normalize_incoming_archive_email

  # Scopes
  scope :active, -> { where(status: "active") }
  scope :suspended, -> { where(status: "suspended") }
  scope :cancelled, -> { where(status: "cancelled") }

  # Methods
  def active?
    status == "active"
  end

  def suspended?
    status == "suspended"
  end

  def cancelled?
    status == "cancelled"
  end

  def branded?
    logo.attached? && acronym.present?
  end

  private

  def generate_code
    self.code = "ENT-#{SecureRandom.alphanumeric(6).upcase}" if code.blank?
  end

  def normalize_prefix
    self.prefix = prefix.upcase if prefix.present?
  end

  def normalize_incoming_archive_email
    self.incoming_archive_email = incoming_archive_email.strip.downcase if incoming_archive_email.present?
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
