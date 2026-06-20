# frozen_string_literal: true

module IncomingMails
  module Actions
    class NotifyActionAssignee < ApplicationAction
      expects :document

      executed do |ctx|
        NotificationJob.perform_later(ctx.document.addressee_id, "mail_action_assigned", ctx.document.id)
      end
    end
  end
end
