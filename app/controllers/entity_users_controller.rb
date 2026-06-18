# frozen_string_literal: true

class EntityUsersController < ApplicationController
  include EntityScoped

  before_action :set_entity_user, only: %i[update destroy edit_departments update_departments]

  def index
    redirect_to entity_settings_path(current_entity)
  end

  def create
    authorize current_entity, :manage_members?

    result = Entities::InviteMemberOrganizer.call(
      entity: current_entity,
      current_user: current_user,
      invited_email: entity_user_params[:invited_email],
      role: entity_user_params[:role],
      department_ids: Array(entity_user_params[:department_ids]).reject(&:blank?),
      primary_department_id: entity_user_params[:primary_department_id]
    )

    if result.success?
      redirect_to entity_settings_path(current_entity), notice: "Invitation sent successfully."
    else
      redirect_to entity_settings_path(current_entity), alert: result.message
    end
  end

  def update
    authorize current_entity, :manage_members?

    if @entity_user.update(role: entity_user_params[:role])
      redirect_to entity_settings_path(current_entity), notice: "Member role updated successfully."
    else
      redirect_to entity_settings_path(current_entity), alert: @entity_user.errors.full_messages.to_sentence
    end
  end

  def destroy
    authorize current_entity, :manage_members?

    @entity_user.destroy
    redirect_to entity_settings_path(current_entity), notice: "Member removed successfully."
  end

  def edit_departments
    authorize current_entity, :manage_members?

    @departments = current_entity.departments.order(:name)
  end

  def update_departments
    authorize current_entity, :manage_members?

    result = Entities::UpdateMemberDepartmentsOrganizer.call(
      entity_user: @entity_user,
      current_user: current_user,
      department_ids: Array(entity_user_departments_params[:department_ids]).reject(&:blank?),
      primary_department_id: entity_user_departments_params[:primary_department_id]
    )

    if result.success?
      redirect_to entity_settings_path(current_entity), notice: "Departments updated successfully."
    else
      redirect_to entity_settings_path(current_entity), alert: result.message
    end
  end

  private

  def set_entity_user
    @entity_user = current_entity.entity_users.find(params[:id])
  end

  def entity_user_params
    params.require(:entity_user).permit(:invited_email, :role, :primary_department_id, department_ids: [])
  end

  def entity_user_departments_params
    params.require(:entity_user).permit(:primary_department_id, department_ids: [])
  end
end
