# frozen_string_literal: true

module Entities
  class DepartmentsController < ApplicationController
    include EntityScoped
    include SavesAndResponds

    before_action :set_department, only: %i[edit update destroy]

    def index
      redirect_to entity_settings_path(current_entity)
    end

    def new
      @department = current_entity.departments.new
      authorize @department
    end

    def create
      @department = current_entity.departments.new(department_params)
      authorize @department

      save_and_respond(@department,
                        success_path: entity_settings_path(current_entity),
                        success_message: "Department created successfully.",
                        failure_template: :new) { @department.save }
    end

    def edit
      authorize @department
    end

    def update
      authorize @department

      save_and_respond(@department,
                        success_path: entity_settings_path(current_entity),
                        success_message: "Department updated successfully.",
                        failure_template: :edit) { @department.update(department_params) }
    end

    def destroy
      authorize @department

      if @department.destroy
        redirect_to entity_settings_path(current_entity), notice: "Department deleted successfully."
      else
        redirect_to entity_settings_path(current_entity), alert: @department.errors.full_messages.to_sentence
      end
    end

    private

    def set_department
      @department = current_entity.departments.find(params[:id])
    end

    def department_params
      params.require(:department).permit(:name, :prefix, :logo, :archive_ingestion_email)
    end
  end
end
