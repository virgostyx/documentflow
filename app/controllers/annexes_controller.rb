# frozen_string_literal: true

class AnnexesController < ApplicationController
  include EntityScoped

  before_action :set_document

  def create
    authorize @document, :update?

    if params.dig(:document, :annex).present?
      @document.annexes.attach(params.dig(:document, :annex))
      redirect_to entity_document_path(current_entity, @document), notice: "Annex added successfully."
    else
      redirect_to entity_document_path(current_entity, @document), alert: "Please select a file to upload."
    end
  end

  def destroy
    authorize @document, :update?

    @document.annexes.attachments.find(params[:id]).purge
    redirect_to entity_document_path(current_entity, @document), notice: "Annex removed successfully."
  end

  private

  def set_document
    @document = current_entity.documents.find(params[:document_id])
  end
end
