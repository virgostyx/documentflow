# frozen_string_literal: true

module Documents
  class FileOrganizer < ApplicationService
    workflow_steps Actions::AssignFolder
  end
end
