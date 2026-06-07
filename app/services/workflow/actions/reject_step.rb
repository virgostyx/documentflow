# frozen_string_literal: true

module Workflow
  module Actions
    class RejectStep < ApplicationAction
      expects :step, :current_user, :reason

      executed do |ctx|
        step = ctx.step
        step.update!(status: "rejected", comment: ctx.reason)

        ctx[:user] = ctx.current_user
        ctx[:auditable] = step.document
        ctx[:action] = "reject_step"
        ctx[:audit_changes] = { workflow_step_id: step.id, role: step.role, reason: ctx.reason }
      end
    end
  end
end
