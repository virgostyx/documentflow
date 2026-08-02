# frozen_string_literal: true

module Documents
  module Actions
    class DestroyDocument < ApplicationAction
      expects :document, :current_user, :reason

      executed do |ctx|
        document = ctx.document
        reference_number = document.reference_number
        subject = document.subject
        document.destroy!

        ctx[:user] = ctx.current_user
        ctx[:auditable] = document
        ctx[:action] = "destroy_document"
        ctx[:audit_changes] = { reason: ctx.reason, reference_number: reference_number, subject: subject }
      end
    end
  end
end
