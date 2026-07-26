# frozen_string_literal: true

module Documents
  module Actions
    class NotifyAddressee < ApplicationAction
      expects :document

      executed do |ctx|
        document = ctx.document
        AddresseeNotificationJob.perform_later(document.addressee_type, document.addressee_id, document.id)
      end
    end
  end
end
