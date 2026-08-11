# frozen_string_literal: true

module Documents
  module Actions
    # Filters a distribution list's members down to those valid for the
    # document's entity, without touching the addressee. Hands the result to
    # the next step (CreateCcRecipientsFromDistributionListMembers).
    class ResolveDistributionListMembers < ApplicationAction
      expects :document, :distribution_list, :current_user
      promises :distribution_list_members, :skipped_count

      executed do |ctx|
        document = ctx.document
        all_members = ctx.distribution_list.distribution_list_members.ordered.to_a
        valid_members = all_members.select { |member| document.party_in_entity?(member.party) }
        ctx.skipped_count = all_members.size - valid_members.size
        ctx.distribution_list_members = valid_members

        ctx[:user] = ctx.current_user
        ctx[:auditable] = document
        ctx[:action] = "add_distribution_list_cc"
        ctx[:audit_changes] = {
          distribution_list_id: ctx.distribution_list.id,
          cc_added: valid_members.size,
          skipped: ctx.skipped_count
        }
      end
    end
  end
end
