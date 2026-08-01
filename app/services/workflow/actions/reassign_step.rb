# frozen_string_literal: true

module Workflow
  module Actions
    class ReassignStep < ApplicationAction
      expects :step, :new_actor, :current_user
      promises :previous_actor

      executed do |ctx|
        step = ctx.step
        ctx.previous_actor = step.actor
        step.update!(actor: ctx.new_actor)

        ctx[:user] = ctx.current_user
        ctx[:auditable] = step.document
        ctx[:action] = "reassign_step"
        ctx[:audit_changes] = {
          workflow_step_id: step.id,
          role: step.role,
          previous_actor_id: ctx.previous_actor&.id,
          new_actor_id: ctx.new_actor.id
        }
      end
    end
  end
end
