# frozen_string_literal: true

module Entities
  module Actions
    class ValidateNotAlreadyMember < ApplicationAction
      expects :entity, :invited_email

      executed do |ctx|
        if ctx.entity.entity_users.exists?(invited_email: ctx.invited_email)
          fail_with!(ctx, "This email address is already a member or has already been invited to this entity", :validation_error)
        end
      end
    end
  end
end
