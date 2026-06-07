# frozen_string_literal: true

module Documents
  module Actions
    class LaunchDocument < ApplicationAction
      expects :document, :current_user

      executed do |ctx|
        document = ctx.document

        unless document.may_launch?
          next fail_with!(ctx, "Ce document ne peut pas être lancé dans son état actuel", :validation_error)
        end

        document.launch!

        ctx[:user] = ctx.current_user
        ctx[:auditable] = document
        ctx[:action] = "launch"
        ctx[:audit_changes] = { status: document.status }
      end
    end
  end
end
