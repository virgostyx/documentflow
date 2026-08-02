# frozen_string_literal: true

module Documents
  class DestroyDocumentOrganizer < ApplicationService
    workflow_steps Actions::DestroyDocument
  end
end
