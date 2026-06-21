# frozen_string_literal: true

module Entities
  class SidebarComponent < ViewComponent::Base
    def initialize(current_entity:, current_user:, current_entity_user: nil)
      @current_entity = current_entity
      @current_user = current_user
      @current_entity_user = current_entity_user
    end

    def overview_count
      documents_base_scope.count
    end

    def received_count
      documents_base_scope.received_by(current_user).count
    end

    def mine_count
      documents_base_scope.authored_by(current_user).count
    end

    def todo_count
      documents_base_scope.todo_for(current_user).count
    end

    def waiting_count
      documents_base_scope.waiting_for(current_user).count
    end

    def info_count
      documents_base_scope.info_for(current_user).count
    end

    def incoming_inbox_count
      incoming_mails_base_scope.received_by(current_user).count
    end

    def pending_triage_count
      incoming_mails_base_scope.pending_triage_for(current_user).count
    end

    def accessible_departments
      @accessible_departments ||= if current_entity_user.nil?
        Department.none
      else
        unrestricted_access? ? current_entity.departments : current_entity_user.departments
      end
    end

    def multiple_departments?
      accessible_departments.count > 1
    end

    def folders_for(department)
      department.folders.includes(:children).select(&:root?)
    end

    def unfiled_count
      documents_base_scope.unfiled.count
    end

    def document_count_for(folder)
      folder_document_counts[folder.id] || 0
    end

    def folder_active?(folder)
      request.query_parameters["folder_id"].to_s == folder.id.to_s
    end

    def unfiled_active?
      request.query_parameters["folder_id"] == "unfiled"
    end

    def documents_section_active?
      request.path.start_with?(entity_documents_path(current_entity)) && !filing_section_active?
    end

    def incoming_mail_section_active?
      request.path.start_with?(entity_incoming_mails_path(current_entity))
    end

    def filing_section_active?
      request.path.start_with?(entity_folders_path(current_entity)) ||
        (request.path == entity_documents_path(current_entity) && request.query_parameters["folder_id"].present?)
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

    def folder_document_counts
      @folder_document_counts ||= documents_base_scope.where.not(folder_id: nil).group(:folder_id).count
    end
  end
end
