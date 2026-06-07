# frozen_string_literal: true

module Workflow
  module Actions
    class ApproveStep < ApplicationAction
      expects :step, :current_user

      executed do |ctx|
        step = ctx.step
        step.update!(status: "approved")

        ctx[:user] = ctx.current_user
        ctx[:auditable] = step.document
        ctx[:action] = "approve_step"
        ctx[:audit_changes] = { workflow_step_id: step.id, role: step.role }
      end
    end
  end
end
