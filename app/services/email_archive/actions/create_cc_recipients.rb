# frozen_string_literal: true

module EmailArchive
  module Actions
    class CreateCcRecipients < ApplicationAction
      expects :document, :entity, :other_recipients

      executed do |ctx|
        ctx.other_recipients.each do |addr|
          contact = ResolveOriginalSenderContact.call(entity: ctx.entity, from_address: addr.address, from_name: addr.display_name)
          next unless contact&.persisted?

          ctx.document.cc_recipients.find_or_create_by!(party_type: "Contact", party_id: contact.id)
        end
      end
    end
  end
end
