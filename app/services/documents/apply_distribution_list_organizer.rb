# frozen_string_literal: true

module Documents
  class ApplyDistributionListOrganizer < ApplicationService
    workflow_steps Actions::SetAddresseeFromDistributionList,
                   Actions::CreateCcRecipientsFromDistributionListMembers
  end
end
