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

  # Append-only: audit trail entries are never edited or removed after the
  # fact. No code path currently updates/destroys an AuditLog; this turns
  # that convention into an enforced invariant. Defends against
  # application-level tampering only, not a DB superuser rewriting rows.
  before_update { raise ActiveRecord::ReadOnlyRecord, "AuditLog records are append-only and cannot be updated" }
  before_destroy { raise ActiveRecord::ReadOnlyRecord, "AuditLog records are append-only and cannot be destroyed" }

  # Class methods
  # ip_address/user_agent are explicit fallbacks for callers with no
  # ActionDispatch::Request available (e.g. an async job) - request, when
  # given, takes precedence since it's the more authoritative source.
  def self.log_event(user:, auditable:, action:, changes: {}, request: nil, ip_address: nil, user_agent: nil)
    create!(
      user: user,
      auditable: auditable,
      action: action,
      change_data: changes,
      ip_address: request&.remote_ip || ip_address,
      user_agent: request&.user_agent || user_agent
    )
  end

  # Instance methods
  def summary
    "#{user.email} #{action} #{auditable_type}##{auditable_id}"
  end
end
