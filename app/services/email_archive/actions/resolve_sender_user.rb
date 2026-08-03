# frozen_string_literal: true

module EmailArchive
  module Actions
    # Resolves the DocumentFlow user who sent the BCC'd email, and confirms
    # they're an authorized member of the target department (owner/admin
    # bypass, mirroring Documents::Actions::ValidateDepartmentMembership) —
    # this doubles as the anti-spoofing boundary: an unrecognized or
    # unauthorized From: address never results in a Document.
    class ResolveSenderUser < ApplicationAction
      expects :mail, :entity, :department
      promises :sender_user

      executed do |ctx|
        address = Array(ctx.mail.from).first
        user = address.present? && (User.find_by(external_email: address) || User.find_by(email: address))
        entity_user = user && EntityUser.active.find_by(entity: ctx.entity, user: user)

        if entity_user && (entity_user.owner? || entity_user.admin? || entity_user.member_of?(ctx.department))
          ctx.sender_user = user
        else
          fail_with!(ctx, "Could not resolve an authorized sender for #{address.inspect}", :validation_error)
        end
      end
    end
  end
end
