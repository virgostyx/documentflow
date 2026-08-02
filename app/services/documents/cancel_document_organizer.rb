# frozen_string_literal: true

module Documents
  class CancelDocumentOrganizer < ApplicationService
    workflow_steps Actions::ValidateCanCancel,
                   Actions::CancelDocument
  end
end
