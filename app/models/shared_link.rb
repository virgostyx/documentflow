# frozen_string_literal: true

class SharedLink < ApplicationRecord
  EXPIRATION_PERIOD = 15.days

  belongs_to :document

  # Validations
  validates :token, presence: true, uniqueness: true
  validates :expires_at, presence: true

  # Callbacks
  before_validation :generate_token
  before_validation :set_expiration

  # Scopes
  scope :active, -> { where("expires_at > ?", Time.current) }
  scope :expired, -> { where("expires_at <= ?", Time.current) }

  # Methods
  def expired?
    expires_at <= Time.current
  end

  def active?
    !expired?
  end

  private

  def generate_token
    self.token = SecureRandom.uuid if token.blank?
  end

  def set_expiration
    self.expires_at = EXPIRATION_PERIOD.from_now if expires_at.blank?
  end
end
