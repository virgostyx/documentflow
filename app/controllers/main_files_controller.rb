# frozen_string_literal: true

class MainFilesController < ApplicationController
  include EntityScoped

  before_action :set_document

  def create
    authorize @document, :update?

    if params.dig(:document, :main_file).present?
      @document.main_file.attach(params.dig(:document, :main_file))
      redirect_to entity_document_path(current_entity, @document), notice: "Main document uploaded successfully."
    else
      redirect_to entity_document_path(current_entity, @document), alert: "Please select a file to upload."
    end
  end

  def destroy
    authorize @document, :update?

    @document.main_file.purge
    redirect_to entity_document_path(current_entity, @document), notice: "Main document removed successfully."
  end

  private

  def set_document
    @document = current_entity.documents.find(params[:document_id])
  end
end
