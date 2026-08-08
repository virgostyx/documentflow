# frozen_string_literal: true

module Documents
  module Actions
    class NotifyCcRecipients < ApplicationAction
      expects :document, :current_user

      executed do |ctx|
        ctx.document.cc_recipients.each do |cc_recipient|
          AuditLog.log_event(
            user: ctx.current_user, auditable: ctx.document, action: "dispatch_queued",
            changes: { recipient_type: cc_recipient.party_type, recipient_id: cc_recipient.party_id, recipient_email: cc_recipient.party.email }
          )
          CcNotificationJob.perform_later(cc_recipient.party_type, cc_recipient.party_id, ctx.document.id, ctx.current_user.id)
        end
      end
    end
  end
end
