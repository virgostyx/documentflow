# frozen_string_literal: true

class InvitationMailer < ApplicationMailer
  def entity_invitation(entity_user)
    entity = entity_user.entity
    inviter = entity_user.invited_by

    mail(
      to: entity_user.invited_email,
      subject: "You're invited to join #{entity.name} on DocumentFlow",
      body: "Hello,\n\n" \
            "#{inviter&.email} invites you to join the entity #{entity.name} on DocumentFlow " \
            "with the role #{entity_user.role}.",
      content_type: "text/plain"
    )
  end
end
