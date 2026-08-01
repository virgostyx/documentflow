# frozen_string_literal: true

module Workflow
  class ReassignStepOrganizer < ApplicationService
    workflow_steps Actions::ValidateActorForReassignment,
                   Actions::ReassignStep,
                   Actions::NotifyReassignedActor
  end
end
