# frozen_string_literal: true

class CcNotificationJob < ApplicationJob
  queue_as :default

  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  def perform(party_type, party_id, document_id, acting_user_id)
    party = party_type.constantize.find(party_id)
    document = Document.find(document_id)
    acting_user = User.find(acting_user_id)

    NotificationMailer.cc_notification(party, document).deliver_now
    log_dispatch(acting_user, document, party_type, party_id, party.email, "dispatch_sent")
  rescue StandardError => e
    log_dispatch(acting_user, document, party_type, party_id, party&.email, "dispatch_failed", error: e.message)
    raise
  end

  private

  def log_dispatch(user, document, party_type, party_id, email, action, error: nil)
    AuditLog.log_event(
      user: user, auditable: document, action: action,
      changes: { recipient_type: party_type, recipient_id: party_id, recipient_email: email, error: error }.compact
    )
    DispatchStatusBroadcastJob.perform_later(document.id)
  end
end
