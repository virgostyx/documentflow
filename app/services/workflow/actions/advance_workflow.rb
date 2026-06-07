# frozen_string_literal: true

module Workflow
  module Actions
    class AdvanceWorkflow < ApplicationAction
      expects :document, :step, :current_user
      promises :workflow_completed, :stage_advanced

      executed do |ctx|
        document = ctx.document
        step = ctx.step
        ctx.workflow_completed = false
        ctx.stage_advanced = false

        stage_steps = if step.parallel? && step.parallel_group.present?
          document.workflow_steps.where(parallel_group: step.parallel_group, is_parallel: true)
        else
          [ step ]
        end

        next if stage_steps.to_a.any?(&:pending?)

        ctx.stage_advanced = true
        document.sign! if step.role == "SIGN" && document.may_sign?

        if document.workflow_steps.ordered.none?(&:pending?)
          ctx.workflow_completed = true

          result = Documents::FinalizeOrganizer.call(document: document, current_user: ctx.current_user)
          fail_with!(ctx, result.message, :finalization_error) if result.failure?
        end
      end
    end
  end
end
