# frozen_string_literal: true

module Entities
  module Actions
    class SendInvitationEmail < ApplicationAction
      expects :entity_user

      executed do |ctx|
        InvitationMailer.entity_invitation(ctx.entity_user).deliver_later
      end
    end
  end
end
