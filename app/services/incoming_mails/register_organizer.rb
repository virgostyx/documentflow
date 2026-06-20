# frozen_string_literal: true

module IncomingMails
  class RegisterOrganizer < ApplicationService
    workflow_steps Documents::Actions::ValidateDepartmentMembership,
                   Actions::ValidateLeadDepartmentMembership,
                   Actions::RegisterIncomingMail,
                   Actions::NotifyLeadAssigned
  end
end
