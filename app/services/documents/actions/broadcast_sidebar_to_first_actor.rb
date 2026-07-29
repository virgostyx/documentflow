# frozen_string_literal: true

module Documents
  module Actions
    class BroadcastSidebarToFirstActor < ApplicationAction
      expects :document

      executed do |ctx|
        actor = ctx.document.reload.current_step&.actor
        SidebarBroadcastJob.perform_later(actor.id, ctx.document.entity_id) if actor
      end
    end
  end
end
