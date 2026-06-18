# frozen_string_literal: true

module Entities
  module Actions
    class ValidateAtLeastOneDepartment < ApplicationAction
      expects :entity_user, :department_ids

      executed do |ctx|
        department_ids = Array(ctx.department_ids).reject(&:blank?)

        if department_ids.empty? && !(ctx.entity_user.owner? || ctx.entity_user.admin?)
          fail_with!(ctx, "This member must be assigned to at least one department", :validation_error)
        end
      end
    end
  end
end
