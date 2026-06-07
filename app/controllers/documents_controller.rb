# frozen_string_literal: true

class DocumentsController < ApplicationController
  include EntityScoped

  before_action :set_document, only: %i[show edit update destroy launch cancel]
  before_action :set_contacts, only: %i[new create edit update]
  before_action :set_entity_members, only: %i[new create edit update]

  def index
    @documents = load_documents
  end

  def search
    @documents = load_documents
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

  def set_contacts
    @contacts = current_entity.contacts.order(:last_name, :first_name)
  end

  def set_entity_members
    @entity_members = current_entity.users.merge(EntityUser.active).order(:email)
  end

  def load_documents
    documents = policy_scope(Document)
                  .where(entity: current_entity)
                  .includes(:sender, :addressee, :created_by)
                  .order(created_at: :desc)
    documents = documents.where("subject ILIKE :q OR reference_number ILIKE :q", q: "%#{params[:q]}%") if params[:q].present?
    documents
  end

  def document_params
    params.require(:document).permit(
      :subject, :document_date, :sender_id, :addressee_id,
      files: [],
      workflow_steps_attributes: %i[id role order actor_id is_parallel parallel_group _destroy]
    )
  end
end
