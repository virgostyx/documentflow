# frozen_string_literal: true

module Entities
  class MemberRowComponent < ViewComponent::Base
    ROLE_COLORS = {
      "owner" => :primary,
      "admin" => :info,
      "member" => :gray,
      "guest" => :gray
    }.freeze

    def initialize(entity_user:, current_user:, entity:)
      @entity_user = entity_user
      @current_user = current_user
      @entity = entity
    end

    private

    attr_reader :entity_user, :current_user, :entity

    def display_name
      entity_user.user&.email || entity_user.invited_email
    end

    def role_label
      entity_user.role.titleize
    end

    def role_color
      ROLE_COLORS[entity_user.role] || :gray
    end

    def manage_members?
      Pundit.policy!(current_user, entity).manage_members?
    end
  end
end
