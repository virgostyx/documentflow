# frozen_string_literal: true

class InvitationMailer < ApplicationMailer
  def entity_invitation(entity_user)
    @entity_user = entity_user
    @entity = entity_user.entity
    @inviter = entity_user.invited_by
    @accept_url = invitation_url(entity_user.invitation_token)

    mail(
      to: entity_user.invited_email,
      subject: "You're invited to join #{@entity.name} on DocumentFlow"
    )
  end
end
