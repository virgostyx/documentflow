# frozen_string_literal: true

module Documents
  module Actions
    class ResendDispatchNotification < ApplicationAction
      expects :document, :current_user, :party, :dispatch_channel, :recipient_type, :recipient_id

      executed do |ctx|
        AuditLog.log_event(
          user: ctx.current_user, auditable: ctx.document, action: "dispatch_queued",
          changes: { recipient_type: ctx.recipient_type, recipient_id: ctx.recipient_id, recipient_email: ctx.party.email }
        )

        job = ctx.dispatch_channel == :addressee ? AddresseeNotificationJob : CcNotificationJob
        job.perform_later(ctx.recipient_type, ctx.recipient_id, ctx.document.id, ctx.current_user.id)
      end
    end
  end
end
