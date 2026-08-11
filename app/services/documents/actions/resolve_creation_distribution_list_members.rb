# frozen_string_literal: true

module Documents
  module Actions
    # The document's addressee was already prefilled from the list's first
    # member on the `new` form (see DocumentsController#new); this resolves
    # the remaining entity-valid members to be added as CC recipients once
    # the document is created.
    class ResolveCreationDistributionListMembers < ApplicationAction
      expects :document, :current_user
      promises :distribution_list_members

      executed do |ctx|
        ctx.distribution_list_members = []

        list = ctx.current_user.distribution_lists.find_by(id: ctx.document.distribution_list_id)
        next if list.nil?

        document = ctx.document
        valid_members = list.distribution_list_members.ordered.select { |member| document.party_in_entity?(member.party) }
        ctx.distribution_list_members = valid_members.drop(1)
      end
    end
  end
end
