# frozen_string_literal: true

module Workflow
  module Actions
    class NotifyNextActor < ApplicationAction
      expects :document, :workflow_completed, :stage_advanced

      executed do |ctx|
        next if ctx.workflow_completed || !ctx.stage_advanced

        actor = ctx.document.reload.current_step&.actor
        NotificationJob.perform_later(actor.id, "action_required", ctx.document.id) if actor
      end
    end
  end
end
