# frozen_string_literal: true

module Documents
  module Actions
    class NotifyCheckedIn < ApplicationAction
      expects :document, :current_user

      executed do |ctx|
        next if ctx[:skip_release]

        document = ctx.document.reload
        recipients = [ document.current_step&.actor, document.created_by ].compact.uniq
        recipients.delete(ctx.current_user)

        recipients.each { |user| NotificationJob.perform_later(user.id, "checked_in", document.id) }
      end
    end
  end
end
