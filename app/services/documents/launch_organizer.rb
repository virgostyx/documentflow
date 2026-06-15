# frozen_string_literal: true

module Documents
  class LaunchOrganizer < ApplicationService
    workflow_steps Actions::ValidateHasCircuit,
                   Actions::ValidateHasMainFile,
                   Actions::LaunchDocument,
                   Actions::CompleteRedStep,
                   Actions::NotifyFirstActor
  end
end
