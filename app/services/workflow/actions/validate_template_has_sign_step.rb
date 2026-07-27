# frozen_string_literal: true

module Workflow
  module Actions
    class ValidateTemplateHasSignStep < ApplicationAction
      expects :circuit_template

      executed do |ctx|
        if ctx.circuit_template.circuit_template_steps.none? { |step| step.role == "SIGN" }
          fail_with!(ctx, "This circuit template has no SIGN step defined", :validation_error)
        end
      end
    end
  end
end
