# frozen_string_literal: true

module Entities
  module Actions
    class AssignDepartments < ApplicationAction
      expects :entity_user, :department_ids, :primary_department_id

      executed do |ctx|
        Array(ctx.department_ids).reject(&:blank?).each do |department_id|
          ctx.entity_user.entity_user_departments.create!(
            department_id: department_id,
            primary: department_id.to_s == ctx.primary_department_id.to_s
          )
        end
      end
    end
  end
end
