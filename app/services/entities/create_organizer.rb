# frozen_string_literal: true

module Entities
  class CreateOrganizer < ApplicationService
    workflow_steps Actions::CreateEntity,
                   Actions::CreateDefaultDepartment,
                   Actions::CreateOwnerEntityUser
  end
end
