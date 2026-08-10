# frozen_string_literal: true

class Department < ApplicationRecord
  include HasValidatedLogo

  belongs_to :entity
  has_many :entity_user_departments, dependent: :destroy
  has_many :entity_users, through: :entity_user_departments
  has_many :documents, dependent: :restrict_with_error
  has_many :document_templates, dependent: :nullify

  validates :name, presence: true, uniqueness: { scope: :entity_id }
  validates :prefix, presence: true,
                      length: { maximum: 8 },
                      format: { with: /\A[A-Z0-9]+\z/, message: "must contain only uppercase letters and digits" },
                      uniqueness: { scope: :entity_id }
  validates :archive_ingestion_email, format: { with: URI::MailTo::EMAIL_REGEXP }, uniqueness: true, allow_blank: true

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
end
