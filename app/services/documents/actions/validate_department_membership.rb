# frozen_string_literal: true

module Documents
  module Actions
    class ValidateDepartmentMembership < ApplicationAction
      expects :entity, :current_user, :document_params

      executed do |ctx|
        entity_user = EntityUser.active.find_by(entity: ctx.entity, user: ctx.current_user)
        next if entity_user&.owner? || entity_user&.admin?

        department = Department.find_by(id: ctx.document_params[:department_id])
        unless entity_user&.member_of?(department)
          fail_with!(ctx, "You are not a member of the selected department", :validation_error)
        end
      end
    end
  end
end
