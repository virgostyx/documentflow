# frozen_string_literal: true

module Entities
  module Actions
    class ValidateNotAlreadyMember < ApplicationAction
      expects :entity, :invited_email

      executed do |ctx|
        if ctx.entity.entity_users.exists?(invited_email: ctx.invited_email)
          fail_with!(ctx, "Cette adresse email est déjà membre ou invitée dans cette entité", :validation_error)
        end
      end
    end
  end
end
