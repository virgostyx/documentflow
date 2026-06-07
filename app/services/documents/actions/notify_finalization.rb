# frozen_string_literal: true

module Documents
  module Actions
    class NotifyFinalization < ApplicationAction
      expects :document

      executed do |ctx|
        document = ctx.document
        NotificationJob.perform_later(document.created_by_id, "action_required", document.id)
      end
    end
  end
end
