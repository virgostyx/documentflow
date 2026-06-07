# frozen_string_literal: true

module Documents
  module Actions
    class NotifyFirstActor < ApplicationAction
      expects :document

      executed do |ctx|
        actor = ctx.document.reload.current_step&.actor
        NotificationJob.perform_later(actor.id, "action_required", ctx.document.id) if actor
      end
    end
  end
end
