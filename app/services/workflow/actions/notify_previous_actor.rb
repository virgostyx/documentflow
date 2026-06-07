# frozen_string_literal: true

module Workflow
  module Actions
    class NotifyPreviousActor < ApplicationAction
      expects :document, :previous_step, :reason

      executed do |ctx|
        actor = ctx.previous_step.actor
        NotificationJob.perform_later(actor.id, "rejection_alert", ctx.document.id, reason: ctx.reason) if actor
      end
    end
  end
end
