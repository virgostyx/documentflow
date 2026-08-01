# frozen_string_literal: true

module Workflow
  module Actions
    class NotifyReassignedActor < ApplicationAction
      expects :step, :new_actor

      executed do |ctx|
        NotificationJob.perform_later(ctx.new_actor.id, "action_required", ctx.step.document_id)
      end
    end
  end
end
