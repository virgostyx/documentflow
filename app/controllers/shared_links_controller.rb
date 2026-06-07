# frozen_string_literal: true

class SharedLinksController < ApplicationController
  include EntityScoped

  layout "pages", only: :show

  skip_before_action :authenticate_user!, only: :show
  skip_before_action :set_current_entity, only: :show
  skip_before_action :authorize_entity_access!, only: :show

  before_action :set_document, only: %i[create destroy]
  before_action :set_shared_link, only: :destroy

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
end
