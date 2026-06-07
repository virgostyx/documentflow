# frozen_string_literal: true

module Entities
  module Actions
    class CreateEntity < ApplicationAction
      expects :entity_params
      promises :entity

      executed do |ctx|
        entity = Entity.new(ctx.entity_params)

        if entity.save
          ctx.entity = entity
        else
          fail_with!(ctx, entity.errors.full_messages.to_sentence, :validation_error)
        end
      end
    end
  end
end
