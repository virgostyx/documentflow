# frozen_string_literal: true

module Documents
  class FinalizeOrganizer < ApplicationService
    workflow_steps Actions::FinalizeDocument,
                   Actions::EnqueuePdfConversion,
                   Actions::NotifyFinalization
  end
end
