# frozen_string_literal: true

class InvitationMailer < ApplicationMailer
  def entity_invitation(entity_user)
    entity = entity_user.entity
    inviter = entity_user.invited_by

    mail(
      to: entity_user.invited_email,
      subject: "Vous êtes invité(e) à rejoindre #{entity.name} sur DocumentFlow",
      body: "Bonjour,\n\n" \
            "#{inviter&.email} vous invite à rejoindre l'entité #{entity.name} sur DocumentFlow " \
            "avec le rôle #{entity_user.role}.",
      content_type: "text/plain"
    )
  end
end
