# frozen_string_literal: true

class NotificationMailer < ApplicationMailer
  def action_required(user, document)
    @user = user
    @document = document
    @document_url = entity_document_url(document.entity, document)

    mail(to: user.email, subject: "Action required: #{document.reference_number}")
  end

  def rejection_alert(user, document, reason)
    @user = user
    @document = document
    @reason = reason
    @document_url = entity_document_url(document.entity, document)

    mail(to: user.email, subject: "Document rejected: #{document.reference_number}")
  end
end
