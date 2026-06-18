# frozen_string_literal: true

module Entities
  class SidebarComponent < ViewComponent::Base
    def initialize(current_entity:, current_user:, current_entity_user: nil)
      @current_entity = current_entity
      @current_user = current_user
      @current_entity_user = current_entity_user
    end

    private

    attr_reader :current_entity, :current_user, :current_entity_user

    def unrestricted_access?
      current_entity_user&.owner? || current_entity_user&.admin?
    end

    def departments
      current_entity_user&.departments || Department.none
    end
  end
end
