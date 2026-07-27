# frozen_string_literal: true

module Documents
  module Actions
    class ValidateHasSignStep < ApplicationAction
      expects :document

      executed do |ctx|
        if ctx.document.workflow_steps.none? { |step| step.role == "SIGN" }
          fail_with!(ctx, "This document's circuit has no SIGN step defined", :validation_error)
        end
      end
    end
  end
end
