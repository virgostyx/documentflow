# frozen_string_literal: true

module Entities
  module Actions
    class CreateInvitation < ApplicationAction
      expects :entity, :current_user, :invited_email, :role
      promises :entity_user

      executed do |ctx|
        entity_user = EntityUser.new(
          entity: ctx.entity,
          invited_email: ctx.invited_email,
          role: ctx.role,
          status: "pending",
          invited_by: ctx.current_user
        )

        if entity_user.save
          ctx.entity_user = entity_user
          ctx[:user] = ctx.current_user
          ctx[:auditable] = entity_user.entity
          ctx[:action] = "invite_member"
          ctx[:audit_changes] = { invited_email: entity_user.invited_email, role: entity_user.role }
        else
          fail_with!(ctx, entity_user.errors.full_messages.to_sentence, :validation_error)
        end
      end
    end
  end
end
