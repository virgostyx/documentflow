# frozen_string_literal: true

class SharedLinksController < ApplicationController
  include EntityScoped

  PUBLIC_ACTIONS = %i[show renew preview_main_file preview_main_file_content preview_annex preview_annex_content].freeze

  layout "pages", only: %i[show renew preview_main_file preview_annex]

  skip_before_action :authenticate_user!, only: PUBLIC_ACTIONS
  skip_before_action :enforce_two_factor_setup, only: PUBLIC_ACTIONS
  skip_before_action :set_current_entity, only: PUBLIC_ACTIONS
  skip_before_action :authorize_entity_access!, only: PUBLIC_ACTIONS

  before_action :set_document, only: %i[create destroy]
  before_action :set_shared_link, only: :destroy
  before_action :load_shared_document, only: %i[preview_main_file preview_main_file_content preview_annex preview_annex_content]

  def show
    @shared_link = SharedLink.find_by(token: params[:token])

    if @shared_link.nil?
      render :unavailable, status: :not_found
    elsif @shared_link.expired?
      render :unavailable, status: :gone
    else
      @document = @shared_link.document
    end
  end

  def renew
    SharedLinks::RequestRenewal.call(token: params[:token], email: params[:email])

    render :renewal_requested
  end

  def preview_main_file
    head :not_found unless @document.main_file.attached?
  end

  def preview_main_file_content
    return head :not_found unless @document.main_file.attached?

    send_data FilePreviewRenderer.pdf_bytes_for(@document.main_file), type: "application/pdf", disposition: "inline"
  rescue PdfConverter::ConversionError
    head :unprocessable_content
  end

  def preview_annex
    @annex = @document.annexes.find(params[:id])
  end

  def preview_annex_content
    annex = @document.annexes.find(params[:id])
    send_data FilePreviewRenderer.pdf_bytes_for(annex.file), type: "application/pdf", disposition: "inline"
  rescue PdfConverter::ConversionError
    head :unprocessable_content
  end

  def create
    @shared_link = @document.shared_links.new
    authorize @shared_link

    if @shared_link.save
      redirect_to entity_document_path(current_entity, @document), notice: "Share link created successfully."
    else
      redirect_to entity_document_path(current_entity, @document), alert: @shared_link.errors.full_messages.to_sentence
    end
  end

  def destroy
    authorize @shared_link
    @shared_link.destroy
    redirect_to entity_document_path(current_entity, @document), notice: "Share link revoked successfully."
  end

  private

  def set_document
    @document = current_entity.documents.find(params[:document_id])
  end

  def set_shared_link
    @shared_link = @document.shared_links.find(params[:id])
  end

  def load_shared_document
    @shared_link = SharedLink.find_by(token: params[:token])
    return head :not_found if @shared_link.nil?
    return head :gone if @shared_link.expired?

    @document = @shared_link.document
  end
end
