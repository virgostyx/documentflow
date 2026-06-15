# frozen_string_literal: true

class CcNotificationJob < ApplicationJob
  queue_as :default

  retry_on StandardError, wait: :exponentially_longer, attempts: 3

  def perform(party_type, party_id, document_id)
    party = party_type.constantize.find(party_id)
    document = Document.find(document_id)

    NotificationMailer.cc_notification(party.email, party.display_name, document).deliver_now
  end
end
