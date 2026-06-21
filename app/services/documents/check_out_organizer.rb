# frozen_string_literal: true

module Documents
  class CheckOutOrganizer < ApplicationService
    workflow_steps Actions::ValidateNotCheckedOut,
                   Actions::CheckOutDocument,
                   Actions::NotifyCheckedOut
  end
end
