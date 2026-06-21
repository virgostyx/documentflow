# frozen_string_literal: true

module Documents
  class CheckInOrganizer < ApplicationService
    workflow_steps Actions::ValidateCheckedOutByActor,
                   Actions::CreateFileVersion,
                   Actions::ReplaceMainFile,
                   Actions::ReleaseCheckout,
                   Actions::NotifyCheckedIn
  end
end
