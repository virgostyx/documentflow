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

        # A step reactivated by ReturnToPreviousStep stays rejected forever otherwise:
        # current_step only looks for "pending", so once this stage clears, the next
        # step in order must be woken back up if a prior rejection left it "rejected".
        next_step = document.workflow_steps.where("\"order\" > ?", stage_steps.to_a.map(&:order).max).ordered.first
        next_step.update!(status: "pending") if next_step&.rejected?

        if step.role == "SIGN" && document.may_sign?
          document.sign!
          PdfConversionJob.perform_later(document.id)
        end

        if document.workflow_steps.ordered.none?(&:pending?)
          ctx.workflow_completed = true

          result = Documents::FinalizeOrganizer.call(document: document, current_user: ctx.current_user)
          fail_with!(ctx, result.message, :finalization_error) if result.failure?
        end
      end
    end
  end
end
