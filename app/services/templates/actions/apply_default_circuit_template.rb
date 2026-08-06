# frozen_string_literal: true

module Templates
  module Actions
    class ApplyDefaultCircuitTemplate < ApplicationAction
      expects :document, :document_template, :current_user

      executed do |ctx|
        circuit_template = ctx.document_template.circuit_template
        next if circuit_template.nil?

        result = Workflow::ApplyCircuitTemplateOrganizer.call(
          document: ctx.document, circuit_template: circuit_template, current_user: ctx.current_user
        )

        fail_with!(ctx, result.message, :validation_error) if result.failure?
      end
    end
  end
end
