# frozen_string_literal: true

module Workflow
  module Actions
    class CloneCircuitTemplateSteps < ApplicationAction
      expects :document, :circuit_template, :current_user
      promises :workflow_steps

      executed do |ctx|
        document = ctx.document
        offset = document.workflow_steps.maximum(:order).to_i

        ctx.workflow_steps = ctx.circuit_template.circuit_template_steps.ordered.map do |template_step|
          document.workflow_steps.create!(
            role: template_step.role,
            order: offset + template_step.order,
            actor_id: template_step.actor_id,
            is_parallel: template_step.is_parallel,
            parallel_group: template_step.parallel_group,
            status: "pending"
          )
        end

        ctx[:user] = ctx.current_user
        ctx[:auditable] = document
        ctx[:action] = "apply_circuit_template"
        ctx[:audit_changes] = { circuit_template_id: ctx.circuit_template.id, steps_added: ctx.workflow_steps.size }
      end
    end
  end
end
