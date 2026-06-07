# frozen_string_literal: true

module Shared
  module Actions
    class LogAuditEvent < ApplicationAction
      expects :user, :auditable, :action
      promises :audit_logged

      executed do |ctx|
        begin
          audit_log = AuditLog.log_event(
            user: ctx.user,
            auditable: ctx.auditable,
            action: ctx.action,
            changes: ctx[:audit_changes] || {},
            request: ctx[:request]
          )

          ctx[:audit_log] = audit_log
          ctx.audit_logged = true

          log_action(ctx, "Audit logged | User: #{ctx.user.email} | Action: #{ctx.action} | " \
                          "Auditable: #{ctx.auditable.class.name}##{ctx.auditable.id}")
        rescue StandardError => e
          log_action(ctx, "Failed to log audit event: #{e.message}", level: :error)
          ctx.audit_logged = false
        end
      end
    end
  end
end
