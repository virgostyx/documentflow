# frozen_string_literal: true

module IncomingMails
  module Actions
    class ValidateActionAssigneeDepartmentMembership < ApplicationAction
      expects :document, :routing_params

      executed do |ctx|
        action_user = User.find_by(id: ctx.routing_params[:action_user_id])
        entity_user = action_user && EntityUser.active.find_by(entity: ctx.document.entity, user: action_user)

        unless entity_user&.member_of?(ctx.document.department)
          fail_with!(ctx, "Action assignee must be a member of the document's department", :validation_error)
        end
      end
    end
  end
end
