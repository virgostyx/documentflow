# frozen_string_literal: true

module Documents
  class CreateOrganizer < ApplicationService
    workflow_steps Actions::ValidateDepartmentMembership,
                   Actions::CreateDocument
  end
end
