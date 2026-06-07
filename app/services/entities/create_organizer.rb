# frozen_string_literal: true

module Entities
  class CreateOrganizer < ApplicationService
    workflow_steps Actions::CreateEntity,
                   Actions::CreateOwnerEntityUser
  end
end
