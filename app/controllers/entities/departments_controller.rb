# frozen_string_literal: true

module Entities
  class DepartmentsController < ApplicationController
    include EntityScoped

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

      if @department.save
        redirect_to entity_settings_path(current_entity), notice: "Department created successfully."
      else
        flash.now[:alert] = @department.errors.full_messages.to_sentence
        render :new, status: :unprocessable_content
      end
    end

    def edit
      authorize @department
    end

    def update
      authorize @department

      if @department.update(department_params)
        redirect_to entity_settings_path(current_entity), notice: "Department updated successfully."
      else
        flash.now[:alert] = @department.errors.full_messages.to_sentence
        render :edit, status: :unprocessable_content
      end
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
      params.require(:department).permit(:name, :prefix, :logo)
    end
  end
end
