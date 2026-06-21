# frozen_string_literal: true

module Documents
  module Actions
    class ReleaseCheckout < ApplicationAction
      expects :document, :current_user, :audit_action

      executed do |ctx|
        ctx.document.update!(checked_out_by: nil, checked_out_at: nil)

        ctx[:user] = ctx.current_user
        ctx[:auditable] = ctx.document
        ctx[:action] = ctx.audit_action
        ctx[:audit_changes] = ctx[:audit_changes] || {}
      end
    end
  end
end
