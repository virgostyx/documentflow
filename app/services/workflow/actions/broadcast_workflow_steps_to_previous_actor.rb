# frozen_string_literal: true

module Workflow
  module Actions
    class BroadcastWorkflowStepsToPreviousActor < ApplicationAction
      expects :document, :previous_step

      executed do |ctx|
        actor = ctx.previous_step.actor
        WorkflowStepsBroadcastJob.perform_later(actor.id, ctx.document.id) if actor
      end
    end
  end
end
