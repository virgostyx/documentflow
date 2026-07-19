# frozen_string_literal: true

module Documents
  class CheckInOrganizer < ApplicationService
    workflow_steps Actions::ValidateCheckedOutByActor,
                   Actions::CreateFileVersions,
                   Actions::ReplaceMainFile,
                   Actions::ReplaceAnnexFiles,
                   Actions::ReleaseCheckout,
                   Actions::NotifyCheckedIn
  end
end
