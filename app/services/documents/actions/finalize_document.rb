# frozen_string_literal: true

module Documents
  module Actions
    class FinalizeDocument < ApplicationAction
      expects :document, :current_user

      executed do |ctx|
        document = ctx.document

        unless document.may_finalize?
          next fail_with!(ctx, "This document must be signed before it can be finalized", :validation_error)
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
