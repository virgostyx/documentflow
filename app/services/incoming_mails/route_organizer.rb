# frozen_string_literal: true

module IncomingMails
  class RouteOrganizer < ApplicationService
    workflow_steps Actions::ValidateActionAssigneeDepartmentMembership,
                   Actions::RouteIncomingMail,
                   Actions::CreateInfoRecipients,
                   Actions::NotifyActionAssignee,
                   Documents::Actions::NotifyCcRecipients
  end
end
