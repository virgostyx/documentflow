# frozen_string_literal: true

module Workflow
  module Actions
    class BroadcastWorkflowStepsToNextActor < ApplicationAction
      expects :document, :workflow_completed, :stage_advanced

      executed do |ctx|
        next if ctx.workflow_completed || !ctx.stage_advanced

        actor = ctx.document.reload.current_step&.actor
        WorkflowStepsBroadcastJob.perform_later(actor.id, ctx.document.id) if actor
      end
    end
  end
end
