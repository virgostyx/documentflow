# frozen_string_literal: true

class DocumentsController < ApplicationController
  include EntityScoped

  before_action :set_document, only: %i[show edit update destroy launch cancel]

  def index
    @list_scope = "all"
    @documents = load_documents(base_scope)
  end

  def mine
    @list_scope = "mine"
    @documents = load_documents(base_scope.authored_by(current_user))
    render :index
  end

  def received
    @list_scope = "received"
    @documents = load_documents(base_scope.received_by(current_user))
    render :index
  end

  def search
    @list_scope = params[:scope].presence || "all"
    @documents = load_documents(scoped_base_for(@list_scope))
    render :index
  end

  def show
    authorize @document
  end

  def new
    @document = current_entity.documents.new
    authorize @document
  end

  def create
    authorize current_entity.documents.new

    result = Documents::CreateOrganizer.call(
      entity: current_entity,
      current_user: current_user,
      document_params: document_params
    )

    if result.success?
      redirect_to entity_document_path(current_entity, result.document), notice: "Document created successfully."
    else
      @document = current_entity.documents.new(document_params)
      flash.now[:alert] = result.message
      render :new, status: :unprocessable_content
    end
  end

  def edit
    authorize @document
  end

  def update
    authorize @document

    if @document.update(document_params)
      redirect_to entity_document_path(current_entity, @document), notice: "Document updated successfully."
    else
      flash.now[:alert] = @document.errors.full_messages.to_sentence
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    authorize @document
    @document.destroy
    redirect_to entity_documents_path(current_entity), notice: "Document deleted successfully."
  end

  def launch
    authorize @document, :launch?

    result = Documents::LaunchOrganizer.call(document: @document, current_user: current_user)

    if result.success?
      redirect_to entity_document_path(current_entity, @document), notice: "Document launched successfully."
    else
      redirect_to entity_document_path(current_entity, @document), alert: result.message
    end
  end

  def cancel
    authorize @document

    if @document.may_cancel? && @document.cancel!
      redirect_to entity_document_path(current_entity, @document), notice: "Document cancelled successfully."
    else
      redirect_to entity_document_path(current_entity, @document), alert: "This document cannot be cancelled in its current state"
    end
  end

  private

  def set_document
    @document = current_entity.documents.find(params[:id])
  end

  def base_scope
    policy_scope(Document).where(entity: current_entity)
  end

  def scoped_base_for(list_scope)
    case list_scope
    when "mine" then base_scope.authored_by(current_user)
    when "received" then base_scope.received_by(current_user)
    else base_scope
    end
  end

  def load_documents(scope)
    documents = scope.includes(:sender, :addressee, :created_by)
    documents = documents.with_status(params[:status])
    documents = documents.where("subject ILIKE :q OR reference_number ILIKE :q", q: "%#{params[:q]}%") if params[:q].present?
    documents.sorted(params[:sort], params[:direction]).page(params[:page])
  end

  def document_params
    params.require(:document).permit(:subject, :document_date, :department_id, :sender_token, :addressee_token)
  end
end
