# frozen_string_literal: true

class AnnexesController < ApplicationController
  include EntityScoped

  before_action :set_document

  def create
    authorize @document, :update?

    if params.dig(:document, :annex).present?
      @document.annexes.create(file: params.dig(:document, :annex))
      redirect_to document_path, notice: "Annex added successfully."
    else
      redirect_to document_path, alert: "Please select a file to upload."
    end
  end

  def destroy
    authorize @document, :update?

    @document.annexes.find(params[:id]).destroy
    redirect_to document_path, notice: "Annex removed successfully."
  end

  def preview
    authorize @document, :show?

    @annex = @document.annexes.find(params[:id])
  end

  def preview_content
    authorize @document, :show?

    annex = @document.annexes.find(params[:id])
    send_data FilePreviewRenderer.pdf_bytes_for(annex.file), type: "application/pdf", disposition: "inline"
  rescue PdfConverter::ConversionError
    head :unprocessable_content
  end

  private

  def set_document
    @document = current_entity.documents.find(params[:document_id])
  end

  def document_path
    @document.outgoing? ? entity_document_path(current_entity, @document) : entity_incoming_mail_path(current_entity, @document)
  end
end
