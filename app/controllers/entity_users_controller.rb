# frozen_string_literal: true

class EntityUsersController < ApplicationController
  include EntityScoped

  before_action :set_entity_user, only: %i[update destroy]

  def index
    @entity_users = current_entity.entity_users.includes(:user).order(:role)
  end

  def create
    authorize current_entity, :manage_members?

    result = Entities::InviteMemberOrganizer.call(
      entity: current_entity,
      current_user: current_user,
      invited_email: entity_user_params[:invited_email],
      role: entity_user_params[:role]
    )

    if result.success?
      redirect_to entity_entity_users_path(current_entity), notice: "Invitation sent successfully."
    else
      redirect_to entity_entity_users_path(current_entity), alert: result.message
    end
  end

  def update
    authorize current_entity, :manage_members?

    if @entity_user.update(role: entity_user_params[:role])
      redirect_to entity_entity_users_path(current_entity), notice: "Member role updated successfully."
    else
      redirect_to entity_entity_users_path(current_entity), alert: @entity_user.errors.full_messages.to_sentence
    end
  end

  def destroy
    authorize current_entity, :manage_members?

    @entity_user.destroy
    redirect_to entity_entity_users_path(current_entity), notice: "Member removed successfully."
  end

  private

  def set_entity_user
    @entity_user = current_entity.entity_users.find(params[:id])
  end

  def entity_user_params
    params.require(:entity_user).permit(:invited_email, :role)
  end
end
