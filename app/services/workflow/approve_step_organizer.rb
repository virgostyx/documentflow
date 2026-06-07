# frozen_string_literal: true

module Workflow
  class ApproveStepOrganizer < ApplicationService
    workflow_steps Actions::ValidateActorCanApprove,
                   Actions::ApproveStep,
                   Actions::AdvanceWorkflow,
                   Actions::NotifyNextActor
  end
end
