# frozen_string_literal: true

module Workflow
  module Actions
    class ValidateActorForReassignment < ApplicationAction
      expects :step, :new_actor

      executed do |ctx|
        entity_id = ctx.step.document.entity_id

        unless EntityUser.active.exists?(entity_id: entity_id, user_id: ctx.new_actor&.id)
          next fail_with!(ctx, "The selected user is not an active member of this entity", :validation_error)
        end
      end
    end
  end
end
