# frozen_string_literal: true

module Documents
  module Actions
    class LaunchDocument < ApplicationAction
      expects :document, :current_user

      executed do |ctx|
        document = ctx.document

        unless document.may_launch?
          next fail_with!(ctx, "This document cannot be launched in its current state", :validation_error)
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
