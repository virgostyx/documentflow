# frozen_string_literal: true

module Workflow
  module Actions
    class ValidateActorCanApprove < ApplicationAction
      expects :step, :current_user
      promises :document

      executed do |ctx|
        step = ctx.step
        ctx.document = step.document

        unless step.pending?
          next fail_with!(ctx, "This step has already been processed", :validation_error)
        end

        unless step.actor == ctx.current_user
          next fail_with!(ctx, "You are not the actor assigned to this step", :permission_error)
        end
      end
    end
  end
end
