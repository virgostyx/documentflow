# frozen_string_literal: true

module Documents
  module Actions
    class CheckOutDocument < ApplicationAction
      expects :document, :current_user

      executed do |ctx|
        document = ctx.document

        document.update!(checked_out_by: ctx.current_user, checked_out_at: Time.current) unless document.checked_out_by?(ctx.current_user)

        ctx[:user] = ctx.current_user
        ctx[:auditable] = document
        ctx[:action] = "check_out"
        ctx[:audit_changes] = {}
      end
    end
  end
end
