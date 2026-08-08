# frozen_string_literal: true

class SidebarBroadcastJob < ApplicationJob
  BADGE_KEYS = %i[overview to_validate received mine todo waiting info incoming_mail].freeze

  queue_as :default
  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  def perform(user_id, entity_id)
    user = User.find(user_id)
    entity = Entity.find(entity_id)
    counts = Entities::SidebarCounts.new(current_entity: entity, current_user: user)

    tags = BADGE_KEYS.map do |key|
      Turbo::StreamsChannel.turbo_stream_action_tag(
        :update,
        target: "sidebar-badge-#{key}",
        template: counts.public_send(:"#{key}_count").to_s
      )
    end

    Turbo::StreamsChannel.broadcast_stream_to(entity, user, :sidebar, content: tags.join)
  end
end
