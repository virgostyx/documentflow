# frozen_string_literal: true

module Documents
  class LaunchOrganizer < ApplicationService
    workflow_steps Actions::ValidateHasCircuit,
                   Actions::ValidateHasSignStep,
                   Actions::ValidateHasMainFile,
                   Actions::LaunchDocument,
                   Actions::NotifyFirstActor
  end
end
