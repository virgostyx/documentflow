# frozen_string_literal: true

module Workflow
  module Actions
    class ValidateTemplateHasSteps < ApplicationAction
      expects :circuit_template

      executed do |ctx|
        if ctx.circuit_template.circuit_template_steps.none?
          fail_with!(ctx, "This circuit template has no steps defined", :validation_error)
        end
      end
    end
  end
end
