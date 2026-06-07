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
          next fail_with!(ctx, "Cette étape a déjà été traitée", :validation_error)
        end

        unless step.actor == ctx.current_user
          next fail_with!(ctx, "Vous n'êtes pas l'acteur assigné à cette étape", :permission_error)
        end
      end
    end
  end
end
