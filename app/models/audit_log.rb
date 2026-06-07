# frozen_string_literal: true

class AuditLog < ApplicationRecord
  belongs_to :user
  belongs_to :auditable, polymorphic: true

  # Validations
  validates :action, presence: true

  # Scopes
  scope :for_user, ->(user_id) { where(user_id: user_id) }
  scope :for_auditable, ->(auditable) { where(auditable: auditable) }
  scope :for_action, ->(action) { where(action: action) }
  scope :recent, -> { order(created_at: :desc) }

  # Class methods
  def self.log_event(user:, auditable:, action:, changes: {}, request: nil)
    create!(
      user: user,
      auditable: auditable,
      action: action,
      change_data: changes,
      ip_address: request&.remote_ip,
      user_agent: request&.user_agent
    )
  end

  # Instance methods
  def summary
    "#{user.email} #{action} #{auditable_type}##{auditable_id}"
  end
end
