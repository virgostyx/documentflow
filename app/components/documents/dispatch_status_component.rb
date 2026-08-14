# frozen_string_literal: true

module Documents
  class DispatchStatusComponent < ViewComponent::Base
    ACTIONS = %w[dispatch_queued dispatch_sent dispatch_failed].freeze

    STATUSES = {
      "dispatch_queued" => { label: "Pending", color: :gray },
      "dispatch_sent" => { label: "Sent", color: :success },
      "dispatch_failed" => { label: "Failed", color: :danger }
    }.freeze

    Row = Struct.new(:label, :status_label, :status_color, :created_at, :recipient_type, :recipient_id, :external, keyword_init: true)

    def initialize(document:, current_user: nil)
      @document = document
      @policy = current_user && Pundit.policy!(current_user, document)
    end

    def dom_id
      ActionView::RecordIdentifier.dom_id(document, :dispatch_status)
    end

    def rows
      logs_by_recipient.map do |_key, logs|
        latest = logs.max_by(&:created_at)
        status = STATUSES.fetch(latest.action)
        type = latest.change_data["recipient_type"]
        id = latest.change_data["recipient_id"]
        party = type.present? && id.present? ? type.constantize.find_by(id: id) : nil

        Row.new(
          label: party&.display_name || latest.change_data["recipient_email"],
          status_label: status[:label], status_color: status[:color], created_at: latest.created_at,
          recipient_type: type, recipient_id: id, external: party&.external? || false
        )
      end.sort_by(&:label)
    end

    def resendable?(row)
      return false unless @policy

      row.external && @policy.resend_dispatch?
    end

    private

    attr_reader :document

    def logs_by_recipient
      document.audit_logs.where(action: ACTIONS)
              .group_by { |log| [ log.change_data["recipient_type"], log.change_data["recipient_id"] ] }
    end
  end
end
