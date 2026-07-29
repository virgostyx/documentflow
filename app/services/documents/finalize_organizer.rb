# frozen_string_literal: true

module Documents
  class FinalizeOrganizer < ApplicationService
    workflow_steps Actions::FinalizeDocument,
                   Actions::NotifyFinalization,
                   Actions::BroadcastSidebarToCreator,
                   Actions::NotifyAddressee,
                   Actions::BroadcastSidebarToAddressee,
                   Actions::NotifyCcRecipients,
                   Actions::BroadcastSidebarToCcRecipients
  end
end
