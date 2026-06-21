# frozen_string_literal: true

module Documents
  module Actions
    class ValidateNotCheckedOut < ApplicationAction
      expects :document, :current_user

      executed do |ctx|
        document = ctx.document

        if document.checked_out? && !document.checked_out_by?(ctx.current_user)
          next fail_with!(ctx, "This document is already checked out by another user", :validation_error)
        end
      end
    end
  end
end
