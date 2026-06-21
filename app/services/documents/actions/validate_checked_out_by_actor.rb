# frozen_string_literal: true

module Documents
  module Actions
    class ValidateCheckedOutByActor < ApplicationAction
      expects :document, :current_user

      executed do |ctx|
        unless ctx.document.checked_out_by?(ctx.current_user)
          next fail_with!(ctx, "You must check out this document before checking in a new version", :permission_error)
        end
      end
    end
  end
end
