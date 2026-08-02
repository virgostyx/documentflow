# frozen_string_literal: true

module Workflow
  module Actions
    class BroadcastWorkflowStepsToReassignedActor < ApplicationAction
      expects :step, :new_actor

      executed do |ctx|
        WorkflowStepsBroadcastJob.perform_later(ctx.new_actor.id, ctx.step.document_id)
      end
    end
  end
end
