# frozen_string_literal: true

module Entities
  class SidebarComponent < ViewComponent::Base
    def initialize(current_entity:, current_user:)
      @current_entity = current_entity
      @current_user = current_user
    end

    private

    attr_reader :current_entity, :current_user
  end
end
