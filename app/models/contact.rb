# frozen_string_literal: true

class Contact < ApplicationRecord
  EMAIL_FORMAT = URI::MailTo::EMAIL_REGEXP

  # Associations
  belongs_to :entity

  # Validations
  validates :first_name, presence: true
  validates :last_name, presence: true
  validates :email, presence: true, format: { with: EMAIL_FORMAT }, uniqueness: { scope: :entity_id }

  # Methods
  def full_name
    "#{first_name} #{last_name}"
  end
end
