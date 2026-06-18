# frozen_string_literal: true

module Entities
  module Actions
    class ReplaceMemberDepartments < ApplicationAction
      expects :entity_user, :current_user, :department_ids, :primary_department_id
      promises :entity_user

      executed do |ctx|
        department_ids = Array(ctx.department_ids).reject(&:blank?)

        ctx.entity_user.entity_user_departments.where.not(department_id: department_ids).destroy_all
        ctx.entity_user.entity_user_departments.update_all(primary: false)

        department_ids.each do |department_id|
          record = ctx.entity_user.entity_user_departments.find_or_create_by!(department_id: department_id)
          record.update_columns(primary: department_id.to_s == ctx.primary_department_id.to_s)
        end

        ctx[:user] = ctx.current_user
        ctx[:auditable] = ctx.entity_user
        ctx[:action] = "update_departments"
        ctx[:audit_changes] = { department_ids: department_ids }
      end
    end
  end
end
