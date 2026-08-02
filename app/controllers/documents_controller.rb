# frozen_string_literal: true

class DocumentsController < ApplicationController
  include EntityScoped

  before_action :set_document, only: %i[show edit update destroy launch cancel confirm_cancel confirm_destroy classify_form classify]
  before_action :load_classification_tree, only: %i[index mine received todo waiting info to_validate search classify_form]

  def index
    @list_scope = "all"
    @documents = load_documents(base_scope.finalized)
  end

  def mine
    @list_scope = "mine"
    @documents = load_documents(base_scope.authored_by(current_user).not_finalized)
    render :index
  end

  def received
    @list_scope = "received"
    @documents = load_documents(base_scope.received_by(current_user).finalized)
    render :index
  end

  def todo
    @list_scope = "todo"
    @documents = load_documents(merged_base_scope.todo_for(current_user).settled)
    render :index
  end

  def waiting
    @list_scope = "waiting"
    @documents = load_documents(merged_base_scope.waiting_for(current_user).settled)
    render :index
  end

  def info
    @list_scope = "info"
    @documents = load_documents(merged_base_scope.info_for(current_user).settled)
    render :index
  end

  def to_validate
    @list_scope = "to_validate"
    @documents = load_documents(current_entity.documents.outgoing.pending_for(current_user))
    render :index
  end

  def search
    @list_scope = params[:scope].presence || "all"
    @documents = load_documents(scoped_base_for(@list_scope))
    render :index
  end

  def show
    authorize @document
    @document_chain = base_scope.where(id: @document.thread.map(&:id))
                                 .includes(:sender, :addressee)
                                 .sort_by { |doc| [ doc.document_date, doc.created_at ] }
  end

  def new
    @document = current_entity.documents.new
    apply_reply_prefill if params[:reply_to].present?
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

    result = Documents::DestroyDocumentOrganizer.call(document: @document, current_user: current_user, reason: params[:reason])

    if result.success?
      redirect_to entity_documents_path(current_entity), notice: "Document deleted successfully."
    else
      redirect_to entity_document_path(current_entity, @document), alert: result.message
    end
  end

  def confirm_destroy
    authorize @document, :destroy?
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

    result = Documents::CancelDocumentOrganizer.call(document: @document, current_user: current_user, reason: params[:reason])

    if result.success?
      redirect_to entity_document_path(current_entity, @document), notice: "Document cancelled successfully."
    else
      redirect_to entity_document_path(current_entity, @document), alert: result.message
    end
  end

  def confirm_cancel
    authorize @document, :cancel?
  end

  def classify_form
    authorize @document, :classify?
  end

  def classify
    authorize @document, :classify?

    if params[:classification_node_id].present?
      node = current_entity.classification_nodes.find_by(id: params[:classification_node_id])
      return redirect_back fallback_location: entity_document_path(current_entity, @document), alert: "That classification node could not be found." if node.nil?
    end

    result = Documents::ClassificationOrganizer.call(document: @document, classification_node: node, current_user: current_user)

    redirect_back fallback_location: entity_document_path(current_entity, @document),
                   notice: result.success? ? result.message : nil,
                   alert: result.success? ? nil : result.message
  end

  private

  def set_document
    @document = current_entity.documents.find(params[:id])
  end

  def base_scope
    policy_scope(Document).where(entity: current_entity).outgoing
  end

  # Only for todo/waiting/info, which now include routed incoming mail.
  # received/mine/to_validate/index must stay outgoing-only — do not reuse this there.
  def merged_base_scope
    policy_scope(Document).where(entity: current_entity)
  end

  def apply_reply_prefill
    original = merged_base_scope.find_by(id: params[:reply_to])
    return unless original
    return if original.incoming? && !original.routed?

    @document.subject = "Re: #{original.subject}"
    @document.department_id = original.department_id
    @document.sender_token = "User-#{current_user.id}"
    @document.addressee_token = "#{original.sender_type}-#{original.sender_id}"
    @document.in_reply_to_id = original.id
  end

  def scoped_base_for(list_scope)
    case list_scope
    when "mine" then base_scope.authored_by(current_user).not_finalized
    when "received" then base_scope.received_by(current_user).finalized
    when "todo" then merged_base_scope.todo_for(current_user).settled
    when "waiting" then merged_base_scope.waiting_for(current_user).settled
    when "info" then merged_base_scope.info_for(current_user).settled
    when "to_validate" then current_entity.documents.outgoing.pending_for(current_user)
    else base_scope.finalized
    end
  end

  def load_documents(scope)
    documents = scope.includes(:sender, :addressee, :created_by)
    documents = documents.with_status(params[:status])
    if params[:q].present?
      documents = documents.where(
        "subject ILIKE :q OR reference_number ILIKE :q OR temporary_number ILIKE :q",
        q: "%#{params[:q]}%"
      )
    end
    documents = apply_classification_filter(documents)
    documents.sorted(params[:sort], params[:direction]).page(params[:page])
  end

  def apply_classification_filter(documents)
    if params[:classification_node_id] == "unclassified"
      documents.unclassified.settled
    elsif params[:classification_node_id].present?
      documents.in_classification_node(params[:classification_node_id]).settled
    else
      documents
    end
  end

  def load_classification_tree
    @classification_roots = ClassificationNode.sort_by_code(
      current_entity.classification_nodes.where(parent_id: nil).includes(children: { children: :children })
    )
  end

  def document_params
    params.require(:document).permit(:subject, :document_date, :department_id, :expects_response, :response_deadline, :sender_token, :addressee_token, :in_reply_to_id)
  end
end
