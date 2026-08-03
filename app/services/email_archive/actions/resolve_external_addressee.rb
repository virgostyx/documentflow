# frozen_string_literal: true

module EmailArchive
  module Actions
    # The first To: recipient becomes the Document's addressee; every other
    # To:/Cc: recipient is carried forward as a raw address for
    # CreateCcRecipients to turn into cc_recipients once the document exists.
    class ResolveExternalAddressee < ApplicationAction
      expects :mail, :entity
      promises :addressee_contact, :other_recipients

      executed do |ctx|
        to_addrs = Array(ctx.mail[:to]&.addrs)
        cc_addrs = Array(ctx.mail[:cc]&.addrs)
        primary, *rest = to_addrs

        if primary.nil?
          fail_with!(ctx, "Message has no To recipient", :validation_error)
        else
          contact = ResolveOriginalSenderContact.call(entity: ctx.entity, from_address: primary.address, from_name: primary.display_name)

          if contact&.persisted?
            ctx.addressee_contact = contact
            ctx.other_recipients = rest + cc_addrs
          else
            fail_with!(ctx, "Could not resolve/create recipient contact for #{primary.address}", :validation_error)
          end
        end
      end
    end
  end
end
