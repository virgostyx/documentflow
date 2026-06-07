# frozen_string_literal: true

module Documents
  class CreateOrganizer < ApplicationService
    workflow_steps Actions::CreateDocument
  end
end
