# frozen_string_literal: true

class IncomingMailsController < ApplicationController
  include EntityScoped

  before_action :set_document, only: %i[show route_form route]

  def index
    @documents = load_documents(base_scope.pending_triage_for(current_user))
  end

  def show
    authorize @document
  end

  def new
    @document = current_entity.documents.new(direction: "incoming")
    authorize @document
  end

  def create
    authorize current_entity.documents.new(direction: "incoming")

    result = IncomingMails::RegisterOrganizer.call(
      entity: current_entity,
      current_user: current_user,
      document_params: document_params
    )

    if result.success?
      redirect_to entity_incoming_mail_path(current_entity, result.document), notice: "Incoming mail registered successfully."
    else
      @document = current_entity.documents.new(document_params.merge(direction: "incoming"))
      flash.now[:alert] = result.message
      render :new, status: :unprocessable_content
    end
  end

  def route_form
    authorize @document, :route?
    @repliable_documents = base_scope.repliable_by(@document.sender).sorted("document_date", "desc")
  end

  def route
    authorize @document, :route?

    result = IncomingMails::RouteOrganizer.call(
      document: @document, current_user: current_user, routing_params: routing_params
    )

    if result.success?
      redirect_to entity_incoming_mail_path(current_entity, @document), notice: "Mail routed successfully."
    else
      @document.assign_attributes(routing_params)
      flash.now[:alert] = result.message
      @repliable_documents = base_scope.repliable_by(@document.sender).sorted("document_date", "desc")
      render :route_form, status: :unprocessable_content
    end
  end

  private

  def set_document
    @document = current_entity.documents.incoming.find(params[:id])
  end

  def base_scope
    policy_scope(Document).where(entity: current_entity)
  end

  def load_documents(scope)
    scope.includes(:sender, :addressee, :created_by).sorted(params[:sort], params[:direction]).page(params[:page])
  end

  def document_params
    params.require(:document).permit(:subject, :document_date, :department_id, :sender_token, :lead_user_id, :main_file, annexes: [])
  end

  def routing_params
    params.require(:document).permit(:action_user_id, :routing_message, :expects_response, :response_deadline, :in_reply_to_id, info_user_ids: [])
  end
end
