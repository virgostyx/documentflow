# frozen_string_literal: true

module Entities
  class SidebarComponent < ViewComponent::Base
    def initialize(current_entity:, current_user:, current_entity_user: nil)
      @current_entity = current_entity
      @current_user = current_user
      @current_entity_user = current_entity_user
    end

    delegate :overview_count, :to_validate_count, :received_count, :mine_count,
             :todo_count, :waiting_count, :info_count, :incoming_mail_count,
             to: :sidebar_counts

    def classification_roots
      ClassificationNode.sort_by_code(current_entity.classification_nodes.where(parent_id: nil).includes(children: { children: :children }))
    end

    def unclassified_count
      sidebar_counts.documents_base_scope.unclassified.finalized.count
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

    def classification_section_active?
      request.path.start_with?(entity_classification_nodes_path(current_entity)) ||
        (request.path == entity_documents_path(current_entity) && request.query_parameters["classification_node_id"].present?)
    end

    def contacts_section_active?
      request.path.start_with?(entity_contacts_path(current_entity)) || request.path.start_with?(distribution_lists_path)
    end

    def settings_section_active?
      request.path.start_with?(entity_settings_path(current_entity))
    end

    private

    attr_reader :current_entity, :current_user, :current_entity_user

    def sidebar_counts
      @sidebar_counts ||= Entities::SidebarCounts.new(current_entity: current_entity, current_user: current_user)
    end

    def unrestricted_access?
      current_entity_user&.owner? || current_entity_user&.admin?
    end

    def departments
      current_entity_user&.departments || Department.none
    end

    def classification_document_counts
      @classification_document_counts ||= sidebar_counts.documents_base_scope.finalized.where.not(classification_node_id: nil).group(:classification_node_id).count
    end
  end
end
