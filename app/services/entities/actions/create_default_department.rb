# frozen_string_literal: true

module Entities
  module Actions
    class CreateDefaultDepartment < ApplicationAction
      expects :entity
      promises :department

      executed do |ctx|
        prefix = "#{ctx.entity.prefix}GEN"[0, 8]
        department = ctx.entity.departments.create(name: "General", is_default: true, prefix: prefix)

        if department.persisted?
          ctx.department = department
        else
          fail_with!(ctx, department.errors.full_messages.to_sentence, :validation_error)
        end
      end
    end
  end
end
