# frozen_string_literal: true

module Documents
  module Actions
    class ValidateCanCancelCheckOut < ApplicationAction
      expects :document, :current_user

      executed do |ctx|
        document = ctx.document

        unless document.checked_out?
          next fail_with!(ctx, "This document is not checked out", :validation_error)
        end

        entity_user = EntityUser.active.find_by(entity_id: document.entity_id, user_id: ctx.current_user.id)
        can_cancel = document.checked_out_by?(ctx.current_user) || entity_user&.owner? || entity_user&.admin?

        unless can_cancel
          next fail_with!(ctx, "You are not allowed to release this checkout", :permission_error)
        end

        ctx[:audit_action] = "cancel_check_out"
      end
    end
  end
end
