# frozen_string_literal: true

class NotificationJob < ApplicationJob
  queue_as :default

  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  def perform(user_id, notification_type, document_id, reason: nil)
    user = User.find(user_id)
    document = Document.find(document_id)

    case notification_type.to_sym
    when :action_required
      NotificationMailer.action_required(user, document).deliver_now
    when :document_finalized
      NotificationMailer.document_finalized(user, document).deliver_now
    when :rejection_alert
      NotificationMailer.rejection_alert(user, document, reason).deliver_now
    when :mail_lead_assigned
      NotificationMailer.mail_lead_assigned(user, document).deliver_now
    when :mail_action_assigned
      NotificationMailer.mail_action_assigned(user, document).deliver_now
    when :checked_out
      NotificationMailer.checked_out(user, document).deliver_now
    when :checked_in
      NotificationMailer.checked_in(user, document).deliver_now
    end
  end
end
