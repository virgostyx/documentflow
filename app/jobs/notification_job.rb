# frozen_string_literal: true

class NotificationJob < ApplicationJob
  queue_as :default

  retry_on StandardError, wait: :exponentially_longer, attempts: 3

  def perform(user_id, notification_type, document_id, reason: nil)
    user = User.find(user_id)
    document = Document.find(document_id)

    case notification_type.to_sym
    when :action_required
      NotificationMailer.action_required(user, document).deliver_now
    when :rejection_alert
      NotificationMailer.rejection_alert(user, document, reason).deliver_now
    end
  end
end
