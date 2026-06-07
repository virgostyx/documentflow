# frozen_string_literal: true

class NotificationMailer < ApplicationMailer
  def action_required(user, document)
    mail(
      to: user.email,
      subject: "Action requise : #{document.reference_number}",
      body: "Bonjour #{user.email},\n\n" \
            "Une action est requise sur le document #{document.reference_number} (#{document.subject}).",
      content_type: "text/plain"
    )
  end

  def rejection_alert(user, document, reason)
    mail(
      to: user.email,
      subject: "Document rejeté : #{document.reference_number}",
      body: "Bonjour #{user.email},\n\n" \
            "Le document #{document.reference_number} (#{document.subject}) a été rejeté.\n\n" \
            "Motif : #{reason}",
      content_type: "text/plain"
    )
  end
end
