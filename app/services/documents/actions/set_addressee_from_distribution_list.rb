# frozen_string_literal: true

module Documents
  module Actions
    # Sets the document's addressee to the first entity-valid member of the
    # list, and hands the remaining valid members to the next step
    # (CreateCcRecipientsFromDistributionListMembers) as CC candidates.
    class SetAddresseeFromDistributionList < ApplicationAction
      expects :document, :distribution_list, :current_user
      promises :distribution_list_members, :skipped_count

      executed do |ctx|
        document = ctx.document
        all_members = ctx.distribution_list.distribution_list_members.ordered.to_a
        valid_members = all_members.select { |member| document.party_in_entity?(member.party) }
        ctx.skipped_count = all_members.size - valid_members.size
        ctx.distribution_list_members = []

        if valid_members.empty?
          fail_with!(ctx, "None of the distribution list's members belong to this document's entity.", :validation_error)
          next
        end

        primary, *rest = valid_members
        document.addressee = primary.party

        unless document.save
          fail_with!(ctx, document.errors.full_messages.to_sentence, :validation_error)
          next
        end

        ctx.distribution_list_members = rest
        ctx[:user] = ctx.current_user
        ctx[:auditable] = document
        ctx[:action] = "apply_distribution_list"
        ctx[:audit_changes] = {
          distribution_list_id: ctx.distribution_list.id,
          addressee_party_token: primary.party_token,
          cc_added: rest.size,
          skipped: ctx.skipped_count
        }
      end
    end
  end
end
