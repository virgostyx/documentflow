# frozen_string_literal: true

module IncomingMails
  module Actions
    class NotifyLeadAssigned < ApplicationAction
      expects :document

      executed do |ctx|
        NotificationJob.perform_later(ctx.document.lead_user_id, "mail_lead_assigned", ctx.document.id)
      end
    end
  end
end
