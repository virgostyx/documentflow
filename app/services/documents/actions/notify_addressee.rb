# frozen_string_literal: true

module Documents
  module Actions
    class NotifyAddressee < ApplicationAction
      expects :document, :current_user

      executed do |ctx|
        document = ctx.document

        AuditLog.log_event(
          user: ctx.current_user, auditable: document, action: "dispatch_queued",
          changes: { recipient_type: document.addressee_type, recipient_id: document.addressee_id, recipient_email: document.addressee.email }
        )
        AddresseeNotificationJob.perform_later(document.addressee_type, document.addressee_id, document.id, ctx.current_user.id)
      end
    end
  end
end
