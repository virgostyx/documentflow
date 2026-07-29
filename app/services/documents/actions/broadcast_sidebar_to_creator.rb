# frozen_string_literal: true

module Documents
  module Actions
    class BroadcastSidebarToCreator < ApplicationAction
      expects :document

      executed do |ctx|
        document = ctx.document
        SidebarBroadcastJob.perform_later(document.created_by_id, document.entity_id)
      end
    end
  end
end
