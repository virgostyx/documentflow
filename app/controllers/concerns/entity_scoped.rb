# frozen_string_literal: true

module EntityScoped
  extend ActiveSupport::Concern

  included do
    layout "entity"

    before_action :set_current_entity
    before_action :authorize_entity_access!
    helper_method :current_entity, :current_entity_user
  end

  private

  def current_entity
    @current_entity
  end

  def current_entity_user
    @current_entity_user ||= EntityUser.active.find_by(entity: current_entity, user: current_user)
  end

  def set_current_entity
    @current_entity = Entity.find(params[:entity_id])
  rescue ActiveRecord::RecordNotFound
    redirect_to dashboard_path, alert: "Entity not found"
  end

  def authorize_entity_access!
    return unless @current_entity

    entity_user = EntityUser.find_by(entity: @current_entity, user: current_user, status: "active")
    redirect_to dashboard_path, alert: "Access denied" unless entity_user
  end
end
