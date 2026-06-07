# frozen_string_literal: true

class NotificationMailer < ApplicationMailer
  def action_required(user, document)
    mail(
      to: user.email,
      subject: "Action required: #{document.reference_number}",
      body: "Hello #{user.email},\n\n" \
            "Action is required on document #{document.reference_number} (#{document.subject}).",
      content_type: "text/plain"
    )
  end

  def rejection_alert(user, document, reason)
    mail(
      to: user.email,
      subject: "Document rejected: #{document.reference_number}",
      body: "Hello #{user.email},\n\n" \
            "Document #{document.reference_number} (#{document.subject}) has been rejected.\n\n" \
            "Reason: #{reason}",
      content_type: "text/plain"
    )
  end
end
