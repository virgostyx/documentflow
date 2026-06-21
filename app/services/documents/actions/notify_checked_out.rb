# frozen_string_literal: true

module Documents
  module Actions
    class NotifyCheckedOut < ApplicationAction
      expects :document, :current_user

      executed do |ctx|
        creator = ctx.document.created_by
        NotificationJob.perform_later(creator.id, "checked_out", ctx.document.id) if creator != ctx.current_user
      end
    end
  end
end
