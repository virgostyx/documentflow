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

    private

    attr_reader :current_entity, :current_user, :current_entity_user

    def documents_base_scope
      Pundit.policy_scope(current_user, Document).where(entity: current_entity)
    end

    def unrestricted_access?
      current_entity_user&.owner? || current_entity_user&.admin?
    end

    def departments
      current_entity_user&.departments || Department.none
    end
  end
end
