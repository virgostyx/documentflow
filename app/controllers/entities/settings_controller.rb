# frozen_string_literal: true

module Entities
  class SettingsController < ApplicationController
    include EntityScoped

    def show
      authorize current_entity
      @entity_users = current_entity.entity_users.includes(:user).order(:role)
    end
  end
end
