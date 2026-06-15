# frozen_string_literal: true

module Documents
  module Actions
    class NotifyCcRecipients < ApplicationAction
      expects :document

      executed do |ctx|
        ctx.document.cc_recipients.each do |cc_recipient|
          CcNotificationJob.perform_later(cc_recipient.party_type, cc_recipient.party_id, ctx.document.id)
        end
      end
    end
  end
end
