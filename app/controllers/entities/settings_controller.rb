# frozen_string_literal: true

module Entities
  class SettingsController < ApplicationController
    include EntityScoped

    def show
      authorize current_entity
      @entity_users = current_entity.entity_users.includes(:user, :departments).order(:role)
      @departments = current_entity.departments.order(:name)
    end
  end
end
