# frozen_string_literal: true

module Documents
  class AuditLogListComponent < ViewComponent::Base
    DESCRIPTIONS = {
      "launch" => ->(_log) { "launched the validation circuit" },
      "apply_circuit_template" => ->(log) { "applied a circuit template (#{log.change_data["steps_added"]} steps)" },
      "approve_step" => ->(log) { "approved the #{log.change_data["role"]} step" },
      "reject_step" => ->(log) { "rejected the #{log.change_data["role"]} step#{reject_reason(log)}" },
      "reassign_step" => ->(log) { "reassigned the #{log.change_data["role"]} step#{reassignment_detail(log)}" },
      "check_out" => ->(_log) { "checked out the document" },
      "check_in" => ->(_log) { "checked in a new version" },
      "cancel_check_out" => ->(_log) { "released the checkout" },
      "classify" => ->(log) { "changed the filing#{classification_detail(log)}" },
      "finalize" => ->(_log) { "finalized the document" },
      "route" => ->(_log) { "routed the incoming mail" },
      "dispatch_queued" => ->(log) { "queued the dispatch email to #{recipient_label(log)}" },
      "dispatch_sent" => ->(log) { "sent the dispatch email to #{recipient_label(log)}" },
      "dispatch_failed" => ->(log) { "failed to send the dispatch email to #{recipient_label(log)}#{dispatch_error_detail(log)}" }
    }.freeze

    def initialize(document:)
      @document = document
    end

    def logs
      document.audit_logs.recent.includes(:user)
    end

    def render?
      logs.any?
    end

    def description(log)
      handler = DESCRIPTIONS[log.action]
      handler ? instance_exec(log, &handler) : log.action.humanize.downcase
    end

    private

    attr_reader :document

    def reject_reason(log)
      log.change_data["reason"].present? ? " — “#{log.change_data["reason"]}”" : ""
    end

    def reassignment_detail(log)
      previous_actor = user_label(log.change_data["previous_actor_id"])
      new_actor = user_label(log.change_data["new_actor_id"])
      previous_actor && new_actor ? " from #{previous_actor} to #{new_actor}" : ""
    end

    def classification_detail(log)
      node_id = log.change_data["classification_node_id"]
      return " (not filed)" if node_id.blank?

      node = ClassificationNode.find_by(id: node_id)
      node ? " to #{node.code} #{node.name}" : ""
    end

    def user_label(id)
      return nil if id.blank?

      User.find_by(id: id)&.display_name || "a former member"
    end

    def recipient_label(log)
      type = log.change_data["recipient_type"]
      id = log.change_data["recipient_id"]
      party = type.present? && id.present? ? type.constantize.find_by(id: id) : nil

      party&.display_name || log.change_data["recipient_email"]
    end

    def dispatch_error_detail(log)
      error = log.change_data["error"]
      error.present? ? " (#{error})" : ""
    end
  end
end
