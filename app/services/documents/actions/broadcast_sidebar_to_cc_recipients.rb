# frozen_string_literal: true

module Documents
  module Actions
    class BroadcastSidebarToCcRecipients < ApplicationAction
      expects :document

      executed do |ctx|
        ctx.document.cc_recipients.where(party_type: "User").each do |cc_recipient|
          SidebarBroadcastJob.perform_later(cc_recipient.party_id, ctx.document.entity_id)
        end
      end
    end
  end
end
