# frozen_string_literal: true

module Documents
  class AddCcRecipientsFromDistributionListOrganizer < ApplicationService
    workflow_steps Actions::ResolveDistributionListMembers,
                   Actions::CreateCcRecipientsFromDistributionListMembers
  end
end
