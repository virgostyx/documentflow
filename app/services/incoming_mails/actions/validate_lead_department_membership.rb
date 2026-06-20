# frozen_string_literal: true

module IncomingMails
  module Actions
    class ValidateLeadDepartmentMembership < ApplicationAction
      expects :document_params

      executed do |ctx|
        department = Department.find_by(id: ctx.document_params[:department_id])
        lead = User.find_by(id: ctx.document_params[:lead_user_id])
        entity_user = lead && EntityUser.active.find_by(entity: department&.entity, user: lead)

        unless entity_user&.member_of?(department)
          fail_with!(ctx, "Lead must be a member of the selected department", :validation_error)
        end
      end
    end
  end
end
