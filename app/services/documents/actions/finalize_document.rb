# frozen_string_literal: true

module Documents
  module Actions
    class FinalizeDocument < ApplicationAction
      expects :document, :current_user

      executed do |ctx|
        document = ctx.document

        unless document.may_finalize?
          next fail_with!(ctx, "Ce document doit être signé avant d'être finalisé", :validation_error)
        end

        document.finalize!

        ctx[:user] = ctx.current_user
        ctx[:auditable] = document
        ctx[:action] = "finalize"
        ctx[:audit_changes] = { status: document.status, is_frozen: document.is_frozen }
      end
    end
  end
end
