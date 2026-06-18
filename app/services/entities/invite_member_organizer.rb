# frozen_string_literal: true

module Entities
  class InviteMemberOrganizer < ApplicationService
    workflow_steps Actions::ValidateNotAlreadyMember,
                   Actions::CreateInvitation,
                   Actions::AssignDepartments,
                   Actions::SendInvitationEmail
  end
end
