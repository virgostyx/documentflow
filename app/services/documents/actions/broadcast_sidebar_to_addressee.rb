# frozen_string_literal: true

module Documents
  module Actions
    class BroadcastSidebarToAddressee < ApplicationAction
      expects :document

      executed do |ctx|
        document = ctx.document
        next unless document.addressee_type == "User"

        SidebarBroadcastJob.perform_later(document.addressee_id, document.entity_id)
      end
    end
  end
end
