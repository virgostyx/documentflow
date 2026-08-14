# frozen_string_literal: true

module Documents
  class ResendDispatchOrganizer < ApplicationService
    workflow_steps Actions::FindDispatchRecipient,
                   Actions::ResendDispatchNotification,
                   audit_log: false
  end
end
