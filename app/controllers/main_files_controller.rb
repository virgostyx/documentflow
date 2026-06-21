# frozen_string_literal: true

class MainFilesController < ApplicationController
  include EntityScoped

  before_action :set_document

  def create
    authorize @document, :update?

    if @document.locked_for?(current_user)
      redirect_to document_path, alert: "This document is checked out by another user."
    elsif params.dig(:document, :main_file).present?
      @document.main_file.attach(params.dig(:document, :main_file))
      redirect_to document_path, notice: "Main document uploaded successfully."
    else
      redirect_to document_path, alert: "Please select a file to upload."
    end
  end

  def destroy
    authorize @document, :update?

    if @document.locked_for?(current_user)
      redirect_to document_path, alert: "This document is checked out by another user."
    else
      @document.main_file.purge
      redirect_to document_path, notice: "Main document removed successfully."
    end
  end

  private

  def set_document
    @document = current_entity.documents.find(params[:document_id])
  end

  def document_path
    @document.outgoing? ? entity_document_path(current_entity, @document) : entity_incoming_mail_path(current_entity, @document)
  end
end
