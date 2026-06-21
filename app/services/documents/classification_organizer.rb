# frozen_string_literal: true

module Documents
  class ClassificationOrganizer < ApplicationService
    workflow_steps Actions::AssignClassification
  end
end
