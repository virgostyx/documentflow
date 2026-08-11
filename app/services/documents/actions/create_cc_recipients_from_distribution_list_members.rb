# frozen_string_literal: true

module Documents
  module Actions
    class CreateCcRecipientsFromDistributionListMembers < ApplicationAction
      expects :document
      expects :distribution_list_members, default: []

      executed do |ctx|
        Array(ctx.distribution_list_members).each do |member|
          cc_recipient = ctx.document.cc_recipients.find_or_initialize_by(party_type: member.party_type, party_id: member.party_id)
          cc_recipient.dispatch_as_attachment = member.dispatch_as_attachment
          next if cc_recipient.save

          fail_with!(ctx, cc_recipient.errors.full_messages.to_sentence, :validation_error)
          break
        end
      end
    end
  end
end
