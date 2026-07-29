# frozen_string_literal: true

module Entities
  class SidebarCounts
    def initialize(current_entity:, current_user:)
      @current_entity = current_entity
      @current_user = current_user
    end

    def overview_count
      documents_base_scope.finalized.count
    end

    def to_validate_count
      current_entity.documents.outgoing.pending_for(current_user).count
    end

    def received_count
      documents_base_scope.received_by(current_user).finalized.count
    end

    def mine_count
      documents_base_scope.authored_by(current_user).not_finalized.count
    end

    def todo_count
      merged_base_scope.todo_for(current_user).settled.count
    end

    def waiting_count
      merged_base_scope.waiting_for(current_user).settled.count
    end

    def info_count
      merged_base_scope.info_for(current_user).settled.count
    end

    def incoming_mail_count
      incoming_mails_base_scope.pending_triage_for(current_user).count
    end

    def documents_base_scope
      Pundit.policy_scope(current_user, Document).where(entity: current_entity).outgoing
    end

    private

    attr_reader :current_entity, :current_user

    # Only for todo/waiting/info, which now include routed incoming mail.
    def merged_base_scope
      Pundit.policy_scope(current_user, Document).where(entity: current_entity)
    end

    def incoming_mails_base_scope
      Pundit.policy_scope(current_user, Document).where(entity: current_entity).incoming
    end
  end
end
