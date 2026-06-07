# frozen_string_literal: true

module Documents
  module Actions
    class ValidateHasCircuit < ApplicationAction
      expects :document

      executed do |ctx|
        if ctx.document.workflow_steps.none?
          fail_with!(ctx, "This document has no validation circuit defined", :validation_error)
        end
      end
    end
  end
end
