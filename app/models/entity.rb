# frozen_string_literal: true

class Entity < ApplicationRecord
  STATUSES = %w[active suspended cancelled].freeze

  # Associations
  has_many :entity_users, dependent: :destroy
  has_many :users, through: :entity_users
  has_many :contacts, dependent: :destroy
  has_many :documents, dependent: :destroy
  has_one_attached :logo

  # Validations
  validates :name, presence: true, uniqueness: true
  validates :code, presence: true, uniqueness: true
  validates :status, presence: true, inclusion: { in: STATUSES }

  # Callbacks
  before_validation :generate_code, on: :create

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

  private

  def generate_code
    self.code = "ENT-#{SecureRandom.alphanumeric(6).upcase}" if code.blank?
  end
end
