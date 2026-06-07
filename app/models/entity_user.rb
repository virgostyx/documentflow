# frozen_string_literal: true

class EntityUser < ApplicationRecord
  ROLES = %w[owner admin member guest].freeze
  STATUSES = %w[pending active suspended].freeze

  # Associations
  belongs_to :entity
  belongs_to :user, optional: true
  belongs_to :invited_by, class_name: "User", optional: true

  # Validations
  validates :role, presence: true, inclusion: { in: ROLES }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :invited_email, presence: true
  validates :user_id, uniqueness: { scope: :entity_id, allow_nil: true }

  # Callbacks
  before_validation :set_invited_at, on: :create
  before_create :generate_invitation_token

  # Scopes
  scope :active, -> { where(status: "active") }
  scope :pending, -> { where(status: "pending") }
  scope :suspended, -> { where(status: "suspended") }
  scope :owners, -> { where(role: "owner") }
  scope :admins, -> { where(role: "admin") }
  scope :members, -> { where(role: "member") }
  scope :guests, -> { where(role: "guest") }

  # Methods
  def owner?
    role == "owner"
  end

  def admin?
    role == "admin"
  end

  def member?
    role == "member"
  end

  def guest?
    role == "guest"
  end

  def active?
    status == "active"
  end

  def pending?
    status == "pending"
  end

  def suspended?
    status == "suspended"
  end

  def accept_for!(accepting_user)
    update!(user: accepting_user, status: "active", accepted_at: Time.current)
  end

  private

  def set_invited_at
    self.invited_at = Time.current if invited_at.blank?
  end

  def generate_invitation_token
    self.invitation_token = SecureRandom.urlsafe_base64(32)
  end
end
