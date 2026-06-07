# frozen_string_literal: true

module Entities
  class EntityCardComponent < ViewComponent::Base
    ROLE_COLORS = {
      "owner" => :primary,
      "admin" => :info,
      "member" => :gray,
      "guest" => :gray
    }.freeze

    def initialize(entity:, current_user:)
      @entity = entity
      @current_user = current_user
    end

    private

    attr_reader :entity, :current_user

    def membership
      @membership ||= entity.entity_users.find_by(user: current_user)
    end

    def role_label
      membership&.role&.titleize
    end

    def role_color
      ROLE_COLORS[membership&.role] || :gray
    end
  end
end
