# frozen_string_literal: true

module Documents
  module Actions
    class CancelDocument < ApplicationAction
      expects :document, :current_user, :reason

      executed do |ctx|
        document = ctx.document
        document.cancel!

        ctx[:user] = ctx.current_user
        ctx[:auditable] = document
        ctx[:action] = "cancel_document"
        ctx[:audit_changes] = { reason: ctx.reason, reference_number: document.reference_number }
      end
    end
  end
end
