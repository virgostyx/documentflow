# frozen_string_literal: true

module Documents
  module Actions
    class ValidateCanCancel < ApplicationAction
      expects :document

      executed do |ctx|
        unless ctx.document.may_cancel?
          next fail_with!(ctx, "This document cannot be cancelled in its current state", :validation_error)
        end
      end
    end
  end
end
