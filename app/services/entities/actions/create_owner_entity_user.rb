# frozen_string_literal: true

module Entities
  module Actions
    class CreateOwnerEntityUser < ApplicationAction
      expects :entity, :current_user
      promises :entity_user

      executed do |ctx|
        entity_user = EntityUser.new(
          entity: ctx.entity,
          user: ctx.current_user,
          invited_email: ctx.current_user.email,
          role: "owner",
          status: "active",
          accepted_at: Time.current
        )

        if entity_user.save
          ctx.entity_user = entity_user
          ctx[:user] = ctx.current_user
          ctx[:auditable] = ctx.entity
          ctx[:action] = "create"
          ctx[:audit_changes] = { name: ctx.entity.name, code: ctx.entity.code }
        else
          fail_with!(ctx, entity_user.errors.full_messages.to_sentence, :validation_error)
        end
      end
    end
  end
end
