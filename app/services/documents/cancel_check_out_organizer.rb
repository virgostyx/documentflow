# frozen_string_literal: true

module Documents
  class CancelCheckOutOrganizer < ApplicationService
    workflow_steps Actions::ValidateCanCancelCheckOut,
                   Actions::ReleaseCheckout
  end
end
