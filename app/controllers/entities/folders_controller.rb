# frozen_string_literal: true

module Entities
  class FoldersController < ApplicationController
    include EntityScoped

    before_action :set_folder, only: %i[edit update confirm_destroy destroy]

    def index
      @departments = accessible_departments.includes(folders: :children)
    end

    def new
      @folder = current_entity.folders.new(department_id: params[:department_id], parent_id: params[:parent_id])
      authorize @folder
    end

    def create
      @folder = current_entity.folders.new(folder_params)
      authorize @folder

      if @folder.save
        redirect_to entity_folders_path(current_entity), notice: "Folder created successfully."
      else
        flash.now[:alert] = @folder.errors.full_messages.to_sentence
        render :new, status: :unprocessable_content
      end
    end

    def edit
      authorize @folder
    end

    def update
      authorize @folder

      if @folder.update(folder_params)
        redirect_to entity_folders_path(current_entity), notice: "Folder updated successfully."
      else
        flash.now[:alert] = @folder.errors.full_messages.to_sentence
        render :edit, status: :unprocessable_content
      end
    end

    def confirm_destroy
      authorize @folder, :destroy?
    end

    def destroy
      authorize @folder

      if @folder.destroy
        redirect_to entity_folders_path(current_entity), notice: "Folder deleted successfully."
      else
        redirect_to entity_folders_path(current_entity), alert: @folder.errors.full_messages.to_sentence
      end
    end

    private

    def set_folder
      @folder = current_entity.folders.find(params[:id])
    end

    def folder_params
      params.require(:folder).permit(:name, :department_id, :parent_id)
    end

    def accessible_departments
      if current_entity_user&.owner? || current_entity_user&.admin?
        current_entity.departments
      else
        current_entity_user&.departments || Department.none
      end
    end
  end
end
