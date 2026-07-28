# frozen_string_literal: true

module Entities
  class SidebarComponent < ViewComponent::Base
    def initialize(current_entity:, current_user:, current_entity_user: nil)
      @current_entity = current_entity
      @current_user = current_user
      @current_entity_user = current_entity_user
    end

    def overview_count
      documents_base_scope.finalized.count
    end

    def to_validate_count
      current_entity.documents.outgoing.pending_for(current_user).count
    end

    def received_count
      documents_base_scope.received_by(current_user).count
    end

    def mine_count
      documents_base_scope.authored_by(current_user).not_finalized.count
    end

    def todo_count
      documents_base_scope.todo_for(current_user).finalized.count
    end

    def waiting_count
      documents_base_scope.waiting_for(current_user).finalized.count
    end

    def info_count
      documents_base_scope.info_for(current_user).finalized.count
    end

    def incoming_inbox_count
      incoming_mails_base_scope.received_by(current_user).count
    end

    def pending_triage_count
      incoming_mails_base_scope.pending_triage_for(current_user).count
    end

    def classification_roots
      ClassificationNode.sort_by_code(current_entity.classification_nodes.where(parent_id: nil).includes(children: { children: :children }))
    end

    def unclassified_count
      documents_base_scope.unclassified.finalized.count
    end

    def document_count_for(node)
      classification_document_counts[node.id] || 0
    end

    def node_active?(node)
      request.query_parameters["classification_node_id"].to_s == node.id.to_s
    end

    def unclassified_active?
      request.query_parameters["classification_node_id"] == "unclassified"
    end

    def can_manage_classification?
      unrestricted_access?
    end

    def documents_section_active?
      request.path.start_with?(entity_documents_path(current_entity)) && !classification_section_active?
    end

    def incoming_mail_section_active?
      request.path.start_with?(entity_incoming_mails_path(current_entity))
    end

    def classification_section_active?
      request.path.start_with?(entity_classification_nodes_path(current_entity)) ||
        (request.path == entity_documents_path(current_entity) && request.query_parameters["classification_node_id"].present?)
    end

    def contacts_section_active?
      request.path.start_with?(entity_contacts_path(current_entity))
    end

    def settings_section_active?
      request.path.start_with?(entity_settings_path(current_entity))
    end

    private

    attr_reader :current_entity, :current_user, :current_entity_user

    def documents_base_scope
      Pundit.policy_scope(current_user, Document).where(entity: current_entity).outgoing
    end

    def incoming_mails_base_scope
      Pundit.policy_scope(current_user, Document).where(entity: current_entity).incoming
    end

    def unrestricted_access?
      current_entity_user&.owner? || current_entity_user&.admin?
    end

    def departments
      current_entity_user&.departments || Department.none
    end

    def classification_document_counts
      @classification_document_counts ||= documents_base_scope.finalized.where.not(classification_node_id: nil).group(:classification_node_id).count
    end
  end
end
