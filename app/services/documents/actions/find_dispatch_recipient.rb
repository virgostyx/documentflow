# frozen_string_literal: true

module Documents
  module Actions
    class FindDispatchRecipient < ApplicationAction
      expects :document, :recipient_type, :recipient_id
      promises :party, :dispatch_channel

      executed do |ctx|
        document = ctx.document
        recipient_id = ctx.recipient_id.to_i
        ctx.recipient_id = recipient_id

        if ctx.recipient_type == document.addressee_type && recipient_id == document.addressee_id
          ctx.party = document.addressee
          ctx.dispatch_channel = :addressee
        else
          cc_recipient = document.cc_recipients.find_by(party_type: ctx.recipient_type, party_id: recipient_id)
          ctx.party = cc_recipient&.party
          ctx.dispatch_channel = :cc
        end

        if ctx.party.nil?
          fail_with!(ctx, "That recipient could not be found on this document.")
        elsif ctx.party.internal?
          fail_with!(ctx, "Only external recipients can be resent a dispatch email.")
        end
      end
    end
  end
end
